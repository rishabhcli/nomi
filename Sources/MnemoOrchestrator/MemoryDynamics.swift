import Foundation

/// A prior version of a memory (audit trail).
public struct MemoryVersion: Equatable, Sendable, Decodable {
    public let memory: String
    public let version: Int
    public init(memory: String, version: Int) { self.memory = memory; self.version = version }
}

/// The engine's memory-entry shape (subset), including its version chain.
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

/// Heuristic contradiction detector: same subject + predicate, different
/// object → supersede. Deterministic; the LLM detector handles paraphrase.
public struct LexicalContradiction: ContradictionDetecting {
    public init() {}

    struct SPO { let subject: String; let predicate: String; let object: String }

    static let predicates = ["live in", "living in", "moved to", "work at", "work in",
                             "based in", "located in", "reside in"]
    static let predicateGroups: [[String]] = [
        ["live in", "living in", "moved to", "reside in", "based in", "located in"],
        ["work at", "work in", "employed at"],
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
