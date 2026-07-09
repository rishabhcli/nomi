import Foundation

// Consolidation.swift — dreaming pass: promote, synthesize, archive (M8).
// Audit: no force-unwraps, try!, or silent empty catches on the query path.

/// Local usage strength for a memory (the engine doesn't expose retrieval
/// counts). Persisted next to the app's data — never egresses.
public struct StrengthRecord: Codable, Equatable, Sendable {
    public var retrievalCount: Int
    public var lastRetrieved: Date
}

/// Persistent strength ledger: strengthens on retrieval, drives archive/promote.
public actor StrengthLedger {
    let path: String
    private var records: [String: StrengthRecord]

    public init(path: String) {
        self.path = path
        if let data = FileManager.default.contents(atPath: path),
           let decoded = try? JSONDecoder().decode([String: StrengthRecord].self, from: data) {
            records = decoded
        } else {
            records = [:]
        }
    }

    public func strengthen(_ id: String, at date: Date = Date()) {
        var r = records[id] ?? StrengthRecord(retrievalCount: 0, lastRetrieved: date)
        r.retrievalCount += 1
        r.lastRetrieved = date
        records[id] = r
        persist()
    }

    public func record(_ id: String) -> StrengthRecord? { records[id] }
    public func all() -> [String: StrengthRecord] { records }
    public func counts() -> [String: Int] { records.mapValues(\.retrievalCount) }

    /// Highest retrieval count first; stable for ties.
    public func rankByStrength(_ ids: [String]) -> [String] {
        ids.enumerated().sorted { a, b in
            let ca = records[a.element]?.retrievalCount ?? 0
            let cb = records[b.element]?.retrievalCount ?? 0
            return ca != cb ? ca > cb : a.offset < b.offset
        }.map(\.element)
    }

    public func remove(_ id: String) { records[id] = nil; persist() }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

/// Pure archive policy: memories untouched past the cold threshold.
public enum ColdArchive {
    // A-334: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-282: intelligence
    // MARK: - Expressiveness (beats-Siri offline)
        /// Shapes cross-doc synthesis as timeline/table/bullets for offline rendering.
        public static func expressivenessShape(_ items: [String], as shape: AnswerShape) -> String {
            switch shape {
            case .timeline: return items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            case .comparison: return "| Item | Detail |\n|------|--------|\n" + items.map { "| \($0) | |" }.joined(separator: "\n")
            case .list: return items.map { "- \($0)" }.joined(separator: "\n")
            default: return items.joined(separator: "; ")
            }
        }

    // A-230: memory
    // MARK: - Memory dynamics (M6)
        /// Active memories only — forgotten and TTL-expired facts are excluded.
        public static func memoryDynamicsActive(_ entry: MemoryEntry, now: Date = Date()) -> Bool {
            guard entry.isLatest && !entry.isForgotten else { return false }
            guard let forgetAfter = entry.forgetAfter,
                  let expiry = ISO8601DateFormatter().date(from: forgetAfter) else { return true }
            return now < expiry
        }

        public static func memoryDynamicsFilter(_ entries: [MemoryEntry], now: Date = Date()) -> [MemoryEntry] {
            entries.filter { memoryDynamicsActive($0, now: now) }
        }

    public static func archivable(records: [String: StrengthRecord], now: Date,
                                  thresholdDays: Int, archiveNeverRetrieved: Bool = false) -> [String] {
        let cutoff = now.addingTimeInterval(-Double(thresholdDays) * 86400)
        return records.filter { _, rec in
            guard rec.lastRetrieved < cutoff else { return false }
            // A-044: conservative default — never archive memories never retrieved.
            if !archiveNeverRetrieved && rec.retrievalCount == 0 { return false }
            return true
        }.keys.sorted()
    }
}

/// Pure promotion policy: recurring dynamic facts graduate to static.
public enum Promotion {
    public static func promotable(retrievalCounts: [String: Int], minAssertions: Int) -> [String] {
        retrievalCounts.filter { $0.value >= minAssertions }.keys.sorted()
    }
}

/// Synthesizes a higher-level memory from a cluster (LLM in the live path).
public protocol PatternSynthesizing: Sendable {
    func synthesize(_ cluster: [MemoryEntry]) async -> String?
}

/// The dreaming pass (PLAN.md M8): promote recurring facts, synthesize
/// patterns from clusters, archive the cold. Runs off the interactive thread.
public struct Consolidator: Sendable {
    // A-190: ingestion
    // MARK: - ingestion
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    let store: MemoryStoring
    let ledger: StrengthLedger
    let container: String?
    let synthesizer: PatternSynthesizing
    let coldThresholdDays: Int
    let promoteMinAssertions: Int
    let archiveNeverRetrieved: Bool

    public init(store: MemoryStoring, ledger: StrengthLedger, container: String?,
                synthesizer: PatternSynthesizing, coldThresholdDays: Int, promoteMinAssertions: Int,
                archiveNeverRetrieved: Bool = false) {
        self.store = store
        self.ledger = ledger
        self.container = container
        self.synthesizer = synthesizer
        self.coldThresholdDays = coldThresholdDays
        self.promoteMinAssertions = promoteMinAssertions
        self.archiveNeverRetrieved = archiveNeverRetrieved
    }

    public func strengthen(_ memId: String) async { await ledger.strengthen(memId) }

    public func dream(now: Date = Date()) async throws {
        let entries = try await store.listMemories(container: container)
        let live = entries.filter { $0.isLatest && !$0.isForgotten }
        let byId = Dictionary(uniqueKeysWithValues: live.map { ($0.id, $0) })

        // 1. Promotion: recurring dynamic facts → static.
        let counts = await ledger.counts()
        for id in Promotion.promotable(retrievalCounts: counts, minAssertions: promoteMinAssertions) {
            guard let m = byId[id], !m.isStatic else { continue }
            _ = try await store.createMemory(content: m.memory, isStatic: true, forgetAfter: nil, container: container)
            try await store.forgetMemory(id: id, reason: RetireReason.superseded.text, container: container)
            await ledger.remove(id)
        }

        // 2. Pattern synthesis over clusters of related dynamic memories.
        //    Idempotent: skip a synthesis whose text already exists as a memory,
        //    so repeated dream passes don't accrete duplicate consolidations
        //    (the synthesized fact is itself dynamic and would re-cluster).
        var existingNorm = Set(live.map { ProfileDedupe.normalize($0.memory) })
        for cluster in Cluster.byKeyword(live.filter { !$0.isStatic }) where cluster.count >= 3 {
            guard let synth = await synthesizer.synthesize(cluster) else { continue }
            let norm = ProfileDedupe.normalize(synth)
            guard !norm.isEmpty, existingNorm.insert(norm).inserted else { continue }
            _ = try await store.createMemory(content: synth, isStatic: false, forgetAfter: nil, container: container)
        }

        // 3. Cold-archive: neglected memories self-archive (retained in store).
        let records = await ledger.all()
        for id in ColdArchive.archivable(records: records, now: now, thresholdDays: coldThresholdDays,
                                         archiveNeverRetrieved: archiveNeverRetrieved) {
            guard byId[id] != nil else { continue }
            try await store.forgetMemory(id: id, reason: "archived (cold)", container: container)
            await ledger.remove(id)
        }
    }
}

/// Cheap keyword clustering for synthesis candidate groups (no embeddings
/// needed for the M8 pass; the synthesizer does the semantic work).
enum Cluster {
    /// Group memories that share a significant keyword; return each group once,
    /// largest first, no memory in two returned groups.
    static func byKeyword(_ memories: [MemoryEntry]) -> [[MemoryEntry]] {
        var keywordToIds: [String: [String]] = [:]
        let byId = Dictionary(uniqueKeysWithValues: memories.map { ($0.id, $0) })
        for m in memories {
            for k in Set(significantKeywords(m.memory)) {
                keywordToIds[k, default: []].append(m.id)
            }
        }
        var used = Set<String>()
        var groups: [[MemoryEntry]] = []
        for (_, ids) in keywordToIds.sorted(by: { $0.value.count > $1.value.count }) {
            let fresh = ids.filter { !used.contains($0) }
            guard fresh.count >= 2 else { continue }
            fresh.forEach { used.insert($0) }
            groups.append(fresh.compactMap { byId[$0] })
        }
        return groups
    }

    static func significantKeywords(_ s: String) -> [String] {
        let stop: Set<String> = ["the", "and", "for", "with", "user", "users", "use", "uses",
                                 "to", "an", "of", "in", "on", "is", "are", "was", "app", "all"]
        return s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 && !stop.contains($0) }
    }
    /// Phase 2: agentic grep deadlock prevention (D-0751+).
    public static func agenticDeadlockSafe(hopQueries: [String]) -> Bool {
        Phase2Techniques.agenticDeadlockSafe(hopQueries: hopQueries)
    }

}
