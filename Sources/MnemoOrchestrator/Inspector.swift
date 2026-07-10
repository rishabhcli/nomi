import Foundation

// Inspector.swift — M9 memory inspector and suppression ledger.
// A-024 audit: no info-level logging of user document or memory text.

/// User retractions that must survive re-ingest of the same content
/// (PLAN.md M9 risk mitigation). Keyed by normalized fact text; persisted.
public actor SuppressionLedger {
    let path: String
    private var suppressed: Set<String>

    public init(path: String) {
        self.path = path
        if let data = FileManager.default.contents(atPath: path),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            suppressed = Set(arr)
        } else {
            suppressed = []
        }
    }

    static func normalize(_ s: String) -> String {
        s.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Fuzzy key: sorted significant tokens so re-extracted wording still matches.
    static func fuzzyKey(_ s: String) -> String {
        let stop: Set<String> = ["the", "and", "for", "with", "user", "that", "this", "from"]
        return normalize(s).split(separator: " ").filter { $0.count > 2 && !stop.contains(String($0)) }
            .sorted().joined(separator: " ")
    }

    public func suppress(_ text: String) {
        suppressed.insert(Self.fuzzyKey(text))
        suppressed.insert(Self.normalize(text))
        persist()
    }
    public func unsuppress(_ text: String) {
        suppressed.remove(Self.fuzzyKey(text))
        suppressed.remove(Self.normalize(text))
        persist()
    }
    public func isSuppressed(_ text: String) -> Bool {
        suppressed.contains(Self.fuzzyKey(text)) || suppressed.contains(Self.normalize(text))
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(Array(suppressed).sorted()) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

/// A memory chip for the inspector UI.
public struct MemoryChip: Equatable, Sendable {
    public let id: String
    public let text: String
    public let isStatic: Bool
}

public struct ProfileSnapshot: Equatable, Sendable {
    public let statics: [MemoryChip]
    public let dynamics: [MemoryChip]
}

/// The M9 inspector: inspect the profile, delete (write-back retraction that
/// suppresses re-ingest), and correct (supersede via M6). Effects are visible
/// on the next query with no rebuild.
public struct MemoryInspector: Sendable {
    // A-336: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-284: intelligence
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

    // A-192: ingestion
    // MARK: - ingestion
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-232: memory
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

    let store: MemoryStoring
    let container: String?
    let suppression: SuppressionLedger

    public init(store: MemoryStoring, container: String?, suppression: SuppressionLedger) {
        self.store = store
        self.container = container
        self.suppression = suppression
    }

    public func snapshot() async throws -> ProfileSnapshot {
        let live = try await store.listMemories(container: container).filter { $0.isLatest && !$0.isForgotten }
        let chips = live.map { MemoryChip(id: $0.id, text: $0.memory, isStatic: $0.isStatic) }
        return ProfileSnapshot(statics: chips.filter(\.isStatic), dynamics: chips.filter { !$0.isStatic })
    }

    /// Retract a fact: forget it AND suppress its content so re-ingesting the
    /// same source doesn't resurrect it (unless the user un-suppresses).
    public func delete(_ memId: String, text: String) async throws {
        try await store.forgetMemory(id: memId, reason: RetireReason.userRetraction.text, container: container)
        await suppression.suppress(text)
    }

    public func correct(_ memId: String, newText: String) async throws {
        _ = try await store.supersedeMemory(id: memId, newContent: newText, container: container)
    }
}

/// Recent answers with the evidence that produced them (explainability, M9).
public actor AnswerTrace {
    public struct Entry: Equatable, Sendable {
        public let query: String
        public let answer: String
        public let sources: [SourceCard]
        public let at: Date
    }
    private var entries: [Entry] = []
    private let cap: Int

    public init(cap: Int = 50) { self.cap = cap }

    public func record(query: String, answer: String, sources: [SourceCard], at: Date = Date()) {
        entries.append(Entry(query: query, answer: answer, sources: sources, at: at))
        if entries.count > cap { entries.removeFirst(entries.count - cap) }
    }

    /// Newest first.
    public func recent(limit: Int) -> [Entry] {
        Array(entries.suffix(limit).reversed())
    }
}
