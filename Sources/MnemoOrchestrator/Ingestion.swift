import Foundation

/// Per-document ingestion state (PLAN.md global data model).
/// The engine is the source of truth; this maps its statuses onto the
/// four-state machine every consumer reads.
public enum ItemState: String, Equatable, Sendable {
    case queued, processing, ready, error

    public init(engineStatus: String) {
        switch engineStatus {
        case "done": self = .ready
        case "failed": self = .error
        case "extracting", "chunking", "embedding", "indexing": self = .processing
        default: self = .queued   // "queued", "unknown", future states
        }
    }

    public var isTerminal: Bool { self == .ready || self == .error }
}

/// Engine document row (subset the orchestrator consumes).
public struct DocumentMeta: Equatable, Sendable {
    public let id: String
    public let filepath: String?
    public let title: String?
    public let status: String
    public let containerTags: [String]?
    public let summary: String?
    public let updatedAt: String?
    public let metadata: [String: String]?
    public var state: ItemState { ItemState(engineStatus: status) }
    public init(id: String, filepath: String?, title: String?, status: String,
                containerTags: [String]?, summary: String?, updatedAt: String?,
                metadata: [String: String]? = nil) {
        self.id = id
        self.filepath = filepath
        self.title = title
        self.status = status
        self.containerTags = containerTags
        self.summary = summary
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
}

/// A single observed state transition.
public struct IngestEvent: Equatable, Sendable {
    public let docId: String
    public let path: String?
    public let from: ItemState?   // nil on first observation
    public let to: ItemState
}

/// Source of document rows (the engine; faked in tests).
public protocol DocumentIndexing: Sendable {
    func documentsList(container: String?) async throws -> [DocumentMeta]
}

/// Mirrors the engine's per-item status into the app: state lookups,
/// transition events, and the queue depth that drives the indexing UI.
public actor IngestIndex {
    let docs: DocumentIndexing
    let container: String?
    private var states: [String: ItemState] = [:]
    private var paths: [String: String] = [:]
    private var continuations: [UUID: AsyncStream<IngestEvent>.Continuation] = [:]

    public init(docs: DocumentIndexing, container: String?) {
        self.docs = docs
        self.container = container
    }

    public func events() -> AsyncStream<IngestEvent> {
        let id = UUID()
        return AsyncStream { c in
            continuations[id] = c
            c.onTermination = { _ in Task { await self.removeContinuation(id) } }
        }
    }

    private func removeContinuation(_ id: UUID) { continuations[id] = nil }

    /// Ends all event streams (tests use this to make iteration finite).
    public func finishEvents() {
        for c in continuations.values { c.finish() }
        continuations.removeAll()
    }

    /// Pull the engine's current view and emit any state transitions.
    /// States are companion-aware: a failed media doc covered by a ready
    /// on-device-extraction companion presents as ready.
    public func refresh() async {
        guard let rows = try? await docs.documentsList(container: container) else { return }
        for row in rows {
            let new = MediaCompanion.effectiveState(of: row, in: rows)
            let old = states[row.id]
            if let p = row.filepath { paths[row.id] = p }
            guard old != new else { continue }
            states[row.id] = new
            let event = IngestEvent(docId: row.id, path: row.filepath, from: old, to: new)
            for c in continuations.values { c.yield(event) }
        }
    }

    public func state(of docId: String) -> ItemState? { states[docId] }

    /// Total documents the engine knows about (any state) — 0 means first-run.
    public var documentCount: Int { states.count }

    /// Documents not yet terminal — drives the "still indexing" surface.
    public var queueDepth: Int { states.values.filter { !$0.isTerminal }.count }

    public func pendingPaths() -> [String] {
        states.filter { !$0.value.isTerminal }.compactMap { paths[$0.key] }.sorted()
    }

    public func failedPaths() -> [String] {
        states.filter { $0.value == .error }.compactMap { paths[$0.key] }.sorted()
    }
}
