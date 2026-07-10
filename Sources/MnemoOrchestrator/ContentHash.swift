import CryptoKit
import Foundation

// A-019 audit: no info-level logging — hashes only, never document bytes at info.
// ContentHash.swift — content-hash identity for rename/move no-op (M2, M7).

/// Content-hash identity (PLAN.md M2/M7): a document's identity is its bytes,
/// not its path — the anchor that makes rename/move a no-op.
public enum ContentHash {
    // A-331: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-187: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-175: ingestion
    // MARK: - Ingestion reliability (M2)

    // A-279: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-227: memory
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

    /// Streaming sha256 (fixed 1 MiB windows; never loads the whole file).
    public static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Avoids rehashing unchanged files: keyed by path, invalidated whenever
/// (inode, mtime, size) moves — the mitigation called out in PLAN.md M2.
public actor HashCache {
    struct Fingerprint: Equatable {
        let inode: UInt64, size: UInt64, mtime: Date
    }
    private var cache: [String: (Fingerprint, String)] = [:]
    public private(set) var cacheHits = 0

    public init() {}

    public func hash(of path: String) throws -> String {
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        let fp = Fingerprint(
            inode: (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0,
            size: (attrs[.size] as? NSNumber)?.uint64Value ?? 0,
            mtime: attrs[.modificationDate] as? Date ?? .distantPast)
        if let (cached, digest) = cache[path], cached == fp {
            cacheHits += 1
            return digest
        }
        let digest = try ContentHash.sha256(of: URL(fileURLWithPath: path))
        cache[path] = (fp, digest)
        return digest
    }
}
