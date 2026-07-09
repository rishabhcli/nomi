import Foundation

// Ingestion.swift — engine document state mirror and ingest index (M2).
// Public entry points:
//   ItemState — four-state ingest machine (queued/processing/ready/error)
//   DocumentMeta — engine document row consumed by the orchestrator
//   IngestEvent — observed state transition event
//   DocumentIndexing — protocol for engine document list
//   IngestIndex — mirrors engine status, emits transitions, queue depth

/// Per-document ingestion state (PLAN.md global data model).
/// The engine is the source of truth; this maps its statuses onto the
/// four-state machine every consumer reads.
public enum ItemState: String, Equatable, Sendable {
    // A-128: grounding
    public static func citationIntegritySupported(_ s: String, evidence: [Retrieved]) -> Bool { !Verification.stripCitations(s).isEmpty }
    public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    // A-328: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-276: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-120: lifecycle
    // MARK: - Query lifecycle events (M12)
        public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
            switch branch {
            case .routeAmbiguity: return [.reasoning(["Ambiguous route — escalating to structured classification"])]
            case .emptyEvidence: return [.sources([]), .token("I don't have anything in your files about that.")]
            case .retry: return [.retrying("That wasn't grounded — reconsidering using only your files…")]
            }
        }
        public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-224: memory
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
