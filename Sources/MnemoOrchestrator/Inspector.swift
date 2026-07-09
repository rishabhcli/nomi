import Foundation

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

    public func suppress(_ text: String) { suppressed.insert(Self.normalize(text)); persist() }
    public func unsuppress(_ text: String) { suppressed.remove(Self.normalize(text)); persist() }
    public func isSuppressed(_ text: String) -> Bool { suppressed.contains(Self.normalize(text)) }

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
