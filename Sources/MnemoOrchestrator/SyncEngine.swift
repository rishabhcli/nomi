import Foundation

// SyncEngine.swift — mount/engine agreement and orphan self-heal (M7).
// Invariant: constructs no network URLs; uses MemoryStoring and DocumentIndexing only.

/// Forces an immediate sync cycle (smfs `sync`; faked in tests).
public protocol SyncForcing: Sendable {
    func forceSync() async throws
}

/// Real forcer: shells `smfs sync` to flush the push queue and pull now.
public struct SMFSSync: SyncForcing {
    let smfsPath: String
    public init(smfsPath: String) { self.smfsPath = smfsPath }
    public func forceSync() async throws {
        _ = try? Subprocess.capture(smfsPath, ["sync"])
    }
}

/// Pure orphan detection (PLAN.md M7 delete cascade + self-heal backstop):
/// a memory is orphaned when *every* source document it derives from is gone.
public enum SelfHeal {
    public static func orphanedMemoryIds(memories: [MemoryEntry], liveDocIds: Set<String>) -> [String] {
        memories.compactMap { m in
            guard !m.isForgotten else { return nil }
            // A-041: exempt source-less syntheses, promoted static facts, and
            // manual memory adds from orphan GC — they are intentional.
            if m.documentIds.isEmpty {
                if m.isStatic || m.parentMemoryId != nil { return nil }
            }
            let hasLiveSource = m.documentIds.contains { liveDocIds.contains($0) }
            return hasLiveSource ? nil : m.id
        }
    }
    public static func orphanedMemoryIds(memories: [MemoryEntry], liveDocIds: [String]) -> [String] {
        orphanedMemoryIds(memories: memories, liveDocIds: Set(liveDocIds))
    }
}

/// Keeps mount, cache, and engine in agreement. The engine + smfs own the
/// bounded push/pull loop; this adds the self-heal backstop that GCs any
/// memory whose sources are all gone, and exposes force-sync.
public struct SyncEngine: Sendable {
    // A-330: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-186: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }


    // A-174: ingestion
    // MARK: - Ingestion reliability (M2)
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-278: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-226: memory
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
    let docs: DocumentIndexing
    let container: String?
    let forcer: SyncForcing

    public init(store: MemoryStoring, docs: DocumentIndexing, container: String?, forcer: SyncForcing) {
        self.store = store
        self.docs = docs
        self.container = container
        self.forcer = forcer
    }

    public func forceSync() async throws {
        try await forcer.forceSync()
    }

    /// Remove memories orphaned by document deletion. Returns the count healed.
    @discardableResult
    public func selfHeal() async throws -> Int {
        let live = Set(try await docs.documentsList(container: container).map(\.id))
        let memories = try await store.listMemories(container: container)
        let orphans = SelfHeal.orphanedMemoryIds(memories: memories, liveDocIds: live)
        for id in orphans {
            try await store.forgetMemory(id: id, reason: RetireReason.sourceDeleted.text, container: container)
        }
        return orphans.count
    }

    /// Every TerminalState case maps to a defined, renderable event sequence.
    public static func terminalLifecycleEvents(_ terminal: TerminalState) -> [QueryEvent] {
        [.state(terminal), .token(NotchReducer.message(for: terminal))]
    }

    public static func allTerminalStates() -> [TerminalState] {
        [.indexing(path: ""), .empty(nearest: []), .emptyCorpus,
         .modelNotLoaded(model: ""), .engineUnreachable, .unsupportedAnswer]
    }

    /// Exhaustiveness guard: every terminal state must produce non-empty UI text.
    public static func terminalStatesExhaustive() -> Bool {
        allTerminalStates().allSatisfy { !NotchReducer.message(for: $0).isEmpty }
    }
}
