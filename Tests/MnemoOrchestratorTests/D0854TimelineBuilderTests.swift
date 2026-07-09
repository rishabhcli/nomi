import XCTest
@testable import MnemoOrchestrator

/// D-0854: answer cache key collision for TimelineBuilder (seed 5b048b98e804).
final class D0854TimelineBuilderTests: XCTestCase {
    private let seed = "5b048b98e804"
    func testCacheKeyCollision_rng() {
        var rng = Phase2RNG(seed: seed)
        let q1 = rng.randomQuery(length: 2)
        let k1 = Phase2Techniques.cacheKey(query: q1 + "  ", container: "mnemo")
        let k2 = Phase2Techniques.cacheKey(query: q1, container: "mnemo")
        XCTAssertEqual(k1, k2)
        XCTAssertTrue(Phase2Techniques.cacheKeysDistinct([(q1, "mnemo"), (q1 + " other", "mnemo")]))
    }

}
