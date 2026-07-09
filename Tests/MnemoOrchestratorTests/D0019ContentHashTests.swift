import XCTest
@testable import MnemoOrchestrator

/// D-0019: ContentHash QueryEvent ordering guarantees (seed 1dbf80db782c).
final class D0019ContentHashTests: XCTestCase {
    private let seed = "1dbf80db782c"

    func testOrderingKeySortsByDocThenSpan() {
        let a = ContentHash.queryEventOrderingKey(docId: "b", charStart: 10, updatedAt: "2026-01-01")
        let b = ContentHash.queryEventOrderingKey(docId: "a", charStart: 99, updatedAt: "2026-01-02")
        XCTAssertGreaterThan(a, b)
    }

    func testOrderedForEventsDeterministic() {
        let hits = [
            Retrieved(memory: "z", similarity: 0.5, source: SourceLocator(docId: "d2", path: "/b", title: "b", charStart: 5)),
            Retrieved(memory: "a", similarity: 0.9, source: SourceLocator(docId: "d1", path: "/a", title: "a", charStart: 1)),
        ]
        let ordered = ContentHash.orderedForEvents(hits)
        XCTAssertEqual(ordered.map(\.source.docId), ["d1", "d2"])
    }

    func testStreamingHashMatchesKnownVector() throws {
        let f = FileManager.default.temporaryDirectory.appending(path: "hash-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: f) }
        try "abc".write(to: f, atomically: true, encoding: .utf8)
        XCTAssertEqual(try ContentHash.sha256(of: f),
                       "sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testProperty_orderingStableUnderPermutation() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<8 {
            var hits: [Retrieved] = []
            for i in 0..<4 {
                hits.append(Retrieved(memory: "m\(i)", similarity: 0.5,
                                      source: SourceLocator(docId: "d\(rng.nextInt(upperBound: 3))",
                                                            path: "/p", title: "t",
                                                            charStart: rng.nextInt(upperBound: 50))))
            }
            let o1 = ContentHash.orderedForEvents(hits)
            let o2 = ContentHash.orderedForEvents(hits.shuffled())
            XCTAssertEqual(o1.map(\.source.docId), o2.map(\.source.docId))
        }
    }
}
