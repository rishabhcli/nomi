import CryptoKit
import Foundation

/// Content-hash identity (PLAN.md M2/M7): a document's identity is its bytes,
/// not its path — the anchor that makes rename/move a no-op.
public enum ContentHash {
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
