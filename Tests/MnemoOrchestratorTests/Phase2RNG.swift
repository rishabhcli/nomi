import Foundation

/// Deterministic PRNG for Phase 2 property tests — seed from each D-NNNN prompt.
struct Phase2RNG: Sendable {
    private var state: UInt64

    init(seed: String) {
        var h: UInt64 = 0x9E37_79B9_7F4A_7C15
        for byte in seed.utf8 {
            h ^= UInt64(byte)
            h &*= 0xBF58_476D_1CE4_E5B9
            h ^= h >> 31
        }
        state = h == 0 ? 0x0A95_DECE_6BD1 : h
    }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextInt(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(nextUInt64() % UInt64(upperBound))
    }

    mutating func randomQuery(length: Int) -> String {
        let words = ["what", "when", "where", "bazel", "rust", "note", "project", "alpha", "beta"]
        var parts: [String] = []
        for _ in 0..<max(1, length) {
            parts.append(words[nextInt(upperBound: words.count)])
        }
        return parts.joined(separator: " ")
    }
}
