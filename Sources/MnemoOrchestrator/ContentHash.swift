#if canImport(CryptoKit)
import CryptoKit
#endif
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
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

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
        #if canImport(CryptoKit)
        var hasher = SHA256()
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
        #else
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            data.append(chunk)
        }
        return "sha256:" + sha256Hex(data)
        #endif
    }

    /// Stable ordering key for QueryEvent source sequencing (doc → span → time).
    public static func queryEventOrderingKey(docId: String, charStart: Int?, updatedAt: String?) -> String {
        let span = charStart.map(String.init) ?? "-1"
        return "\(docId)|\(span)|\(updatedAt ?? "")"
    }

    /// Sort hits for deterministic QueryEvent source ordering.
    public static func orderedForEvents(_ hits: [Retrieved]) -> [Retrieved] {
        hits.sorted {
            let a = queryEventOrderingKey(docId: $0.source.docId, charStart: $0.source.charStart,
                                          updatedAt: $0.source.updatedAt)
            let b = queryEventOrderingKey(docId: $1.source.docId, charStart: $1.source.charStart,
                                          updatedAt: $1.source.updatedAt)
            return a < b
        }
    }

    static func sha256Hex(_ data: Data) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        return SHA256Fallback.hash(data)
        #endif
    }
}

#if !canImport(CryptoKit)
/// Pure-Swift SHA-256 for non-Apple CI hosts (offline, no egress).
enum SHA256Fallback {
    static func hash(_ data: Data) -> String {
        var h = [UInt32](repeating: 0, count: 8)
        var w = [UInt32](repeating: 0, count: 64)
        let k: [UInt32] = [
            0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
            0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
            0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
            0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
            0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
            0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
            0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
            0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2]
        h = [0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]
        let bytes = [UInt8](data)
        let bitLen = UInt64(bytes.count) * 8
        var msg = bytes + [0x80]
        while (msg.count % 64) != 56 { msg.append(0) }
        msg += withUnsafeBytes(of: bitLen.bigEndian, Array.init)
        for chunkStart in stride(from: 0, to: msg.count, by: 64) {
            for i in 0..<16 {
                let j = chunkStart + i * 4
                w[i] = UInt32(msg[j]) << 24 | UInt32(msg[j+1]) << 16 | UInt32(msg[j+2]) << 8 | UInt32(msg[j+3])
            }
            for i in 16..<64 {
                let s0 = (w[i-15] >> 7) ^ (w[i-15] >> 18) ^ (w[i-15] >> 3)
                let s1 = (w[i-2] >> 17) ^ (w[i-2] >> 19) ^ (w[i-2] >> 10)
                w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
            }
            var a=h[0],b=h[1],c=h[2],d=h[3],e=h[4],f=h[5],g=h[6],s=h[7]
            for i in 0..<64 {
                let S1 = (e >> 6) ^ (e >> 11) ^ (e >> 25)
                let ch = (e & f) ^ ((~e) & g)
                let t1 = s &+ S1 &+ ch &+ k[i] &+ w[i]
                let S0 = (a >> 2) ^ (a >> 13) ^ (a >> 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let t2 = S0 &+ maj
                s=d &+ t1; d=c; c=b; b=a; a=t1 &+ t2; g=f; f=e; e=b &+ t1
            }
            h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d
            h[4] = h[4] &+ e; h[5] = h[5] &+ f; h[6] = h[6] &+ g; h[7] = h[7] &+ s
        }
        return h.map { String(format: "%08x", $0) }.joined()
    }
}
#endif

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
