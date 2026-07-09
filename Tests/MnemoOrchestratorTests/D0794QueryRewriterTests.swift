import XCTest
@testable import MnemoOrchestrator

/// D-0794: answer cache key collision for QueryRewriter (seed 366d792edfa2).
final class D0794QueryRewriterTests: XCTestCase {
    private let seed = "366d792edfa2"
    func testCacheKeyCollision_rng() {
        var rng = Phase2RNG(seed: seed)
        let q1 = rng.randomQuery(length: 2)
        let k1 = Phase2Techniques.cacheKey(query: q1 + "  ", container: "mnemo")
        let k2 = Phase2Techniques.cacheKey(query: q1, container: "mnemo")
        XCTAssertEqual(k1, k2)
        XCTAssertTrue(Phase2Techniques.cacheKeysDistinct([(q1, "mnemo"), (q1 + " other", "mnemo")]))
    }

}
