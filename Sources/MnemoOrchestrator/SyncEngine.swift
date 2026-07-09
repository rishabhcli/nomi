import Foundation

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
            // No sources, or all sources gone → orphan.
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
}
