import Foundation

// MemoryDynamics.swift — memory versioning, supersession, contradiction (M6).
// Public types: MemoryVersion, MemoryEntry, MemoryStoring, ContradictionDetecting,
//   MemoryDynamics, LexicalContradiction — serve M6 memory dynamics milestone.

/// A prior version of a memory (audit trail). M6.
public struct MemoryVersion: Equatable, Sendable, Decodable {
    public let memory: String
    public let version: Int
    public init(memory: String, version: Int) { self.memory = memory; self.version = version }
}

/// The engine's memory-entry shape (subset), including its version chain. M6.
public struct MemoryEntry: Equatable, Sendable, Decodable {
    public let id: String
    public let memory: String
    public let version: Int
    public let isLatest: Bool
    public let isForgotten: Bool
    public let isStatic: Bool
    public let parentMemoryId: String?
    public let rootMemoryId: String?
    public let forgetAfter: String?
    public let forgetReason: String?
    public let history: [MemoryVersion]
    public let documentIds: [String]   // source docs this memory was derived from
    public init(id: String, memory: String, version: Int, isLatest: Bool, isForgotten: Bool,
                isStatic: Bool, parentMemoryId: String?, rootMemoryId: String?,
                forgetAfter: String?, forgetReason: String?, history: [MemoryVersion],
                documentIds: [String] = []) {
        self.id = id; self.memory = memory; self.version = version; self.isLatest = isLatest
        self.isForgotten = isForgotten; self.isStatic = isStatic; self.parentMemoryId = parentMemoryId
        self.rootMemoryId = rootMemoryId; self.forgetAfter = forgetAfter
        self.forgetReason = forgetReason; self.history = history; self.documentIds = documentIds
    }
    enum CodingKeys: String, CodingKey {
        case id, memory, version, isLatest, isForgotten, isStatic
        case parentMemoryId, rootMemoryId, forgetAfter, forgetReason, history, documentIds
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        memory = try c.decode(String.self, forKey: .memory)
        version = try c.decode(Int.self, forKey: .version)
        isLatest = try c.decodeIfPresent(Bool.self, forKey: .isLatest) ?? true
        isForgotten = try c.decodeIfPresent(Bool.self, forKey: .isForgotten) ?? false
        isStatic = try c.decodeIfPresent(Bool.self, forKey: .isStatic) ?? false
        parentMemoryId = try c.decodeIfPresent(String.self, forKey: .parentMemoryId)
        rootMemoryId = try c.decodeIfPresent(String.self, forKey: .rootMemoryId)
        forgetAfter = try c.decodeIfPresent(String.self, forKey: .forgetAfter)
        forgetReason = try c.decodeIfPresent(String.self, forKey: .forgetReason)
        history = try c.decodeIfPresent([MemoryVersion].self, forKey: .history) ?? []
        documentIds = try c.decodeIfPresent([String].self, forKey: .documentIds) ?? []
    }
}

public enum RetireReason: Sendable {
    case userRetraction, superseded, sourceDeleted, expired, custom(String)
    public var text: String {
        switch self {
        case .userRetraction: return "user retraction"
        case .superseded: return "superseded"
        case .sourceDeleted: return "source deleted"
        case .expired: return "expired"
        case .custom(let s): return s
        }
    }
}

/// Engine memory mutations (faked in tests).
public protocol MemoryStoring: Sendable {
    func createMemory(content: String, isStatic: Bool, forgetAfter: String?, container: String?) async throws -> String
    func supersedeMemory(id: String, newContent: String, container: String?) async throws -> String
    func forgetMemory(id: String, reason: String, container: String?) async throws
    func listMemories(container: String?) async throws -> [MemoryEntry]
}

/// Decides whether a new fact supersedes an existing one.
public protocol ContradictionDetecting: Sendable {
    func supersededFact(byNew newFact: String, among candidates: [MemoryEntry]) async -> String?
}

/// Keeps the graph correct over time (PLAN.md M6): a contradicting fact
/// supersedes its predecessor in place instead of accumulating; novel facts
/// are created; retirement is a soft-delete with an audited reason.
public struct MemoryDynamics: Sendable {
    // A-332: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-188: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-176: ingestion
    // MARK: - Ingestion reliability (M2)
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-280: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-228: memory
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
    let detector: ContradictionDetecting
    let suppression: SuppressionLedger?

    public init(store: MemoryStoring, container: String?, detector: ContradictionDetecting,
                suppression: SuppressionLedger? = nil) {
        self.store = store
        self.container = container
        self.detector = detector
        self.suppression = suppression
    }

    public func onNewFacts(_ facts: [String], from docId: String) async throws {
        let existing = (try? await store.listMemories(container: container)) ?? []
        for fact in facts {
            // A user-retracted fact stays retracted even if its source is re-ingested (M9).
            if let suppression, await suppression.isSuppressed(fact) { continue }
            if let victimId = await detector.supersededFact(byNew: fact, among: existing) {
                _ = try await store.supersedeMemory(id: victimId, newContent: fact, container: container)
            } else {
                _ = try await store.createMemory(content: fact, isStatic: false, forgetAfter: nil, container: container)
            }
        }
    }

    public func softDelete(_ memId: String, reason: RetireReason) async throws {
        try await store.forgetMemory(id: memId, reason: reason.text, container: container)
    }

    /// Audit trail: current text first, then prior versions newest→oldest.
    public func history(of rootOrId: String) async throws -> [MemoryVersion] {
        let all = try await store.listMemories(container: container)
        guard let entry = all.first(where: { $0.id == rootOrId || $0.rootMemoryId == rootOrId }) else { return [] }
        return [MemoryVersion(memory: entry.memory, version: entry.version)] + entry.history
    }
}

/// Stable JSON schema for mnemoctl memory-dynamics output.
public struct MemoryDynamicsSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let container: String?
    public let activeCount: Int
    public let entries: [MemoryEntry]

    public init(container: String?, entries: [MemoryEntry], now: Date = Date()) {
        self.schemaVersion = 1
        self.container = container
        let active = MemoryFactFilter.filterActive(entries, now: now)
        self.activeCount = active.count
        self.entries = active
    }

    public func jsonData() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(self)
    }
}

extension MemoryDynamics {
    /// mnemoctl JSON schema stability hook (D-0070+).
    public static func jsonExportData() throws -> Data {
        try MemoryDynamicsSnapshot(container: "mnemo", entries: []).jsonData()
    }
}


/// Filters memories for active use: not forgotten, not TTL-expired, latest version.
public enum MemoryFactFilter {
    private static let iso = ISO8601DateFormatter()

    public static func isActive(_ e: MemoryEntry, now: Date = Date()) -> Bool {
        guard e.isLatest && !e.isForgotten else { return false }
        guard let forgetAfter = e.forgetAfter else { return true }
        guard let expiry = iso.date(from: forgetAfter) else { return false }
        return now < expiry
    }

    public static func filterActive(_ entries: [MemoryEntry], now: Date = Date()) -> [MemoryEntry] {
        entries.filter { isActive($0, now: now) }
    }

    public static func filterProfile(_ profile: Profile, activeTexts: Set<String>) -> Profile {
        Profile(
            statics: profile.statics.filter { activeTexts.contains($0) },
            dynamics: profile.dynamics.filter { activeTexts.contains($0) },
            memories: profile.memories.filter { activeTexts.contains($0.memory) })
    }
}

/// Heuristic contradiction detector: same subject + predicate, different
/// object → supersede. Deterministic; the LLM detector handles paraphrase.
public struct LexicalContradiction: ContradictionDetecting {
    public init() {}

    struct SPO { let subject: String; let predicate: String; let object: String }

    static let predicates = ["prefers", "favorite", "favourite", "likes", "live in", "living in", "moved to", "work at", "work in",
                             "based in", "located in", "reside in",
                             "started on", "ended on", "married to", "reports to", "manages",
                             "costs", "worth", "salary of", "earns"]
    static let predicateGroups: [[String]] = [
        ["live in", "living in", "moved to", "reside in", "based in", "located in"],
        ["work at", "work in", "employed at"],
        ["started on", "began on", "ended on", "finished on"],
        ["married to", "reports to", "manages"],
        ["costs", "worth", "salary of", "earns"],
    ]

    static func parse(_ s: String) -> SPO? {
        let lower = s.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".!? "))
        for pred in predicates where lower.contains(" \(pred) ") || lower.hasPrefix("\(pred) ") {
            let parts = lower.components(separatedBy: " \(pred) ")
            guard parts.count == 2 else { continue }
            return SPO(subject: parts[0].trimmingCharacters(in: .whitespaces),
                       predicate: canonicalPredicate(pred),
                       object: parts[1].trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    static func canonicalPredicate(_ p: String) -> String {
        for group in predicateGroups where group.contains(p) { return group[0] }
        return p
    }

    public func supersededFact(byNew newFact: String, among candidates: [MemoryEntry]) async -> String? {
        guard let new = Self.parse(newFact) else { return nil }
        for c in candidates where c.isLatest && !c.isForgotten {
            guard let old = Self.parse(c.memory) else { continue }
            if old.subject == new.subject, old.predicate == new.predicate, old.object != new.object {
                return c.id
            }
        }
        return nil
    }
}
