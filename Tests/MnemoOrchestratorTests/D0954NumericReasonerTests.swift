import XCTest
@testable import MnemoOrchestrator

/// D-0954: answer cache key collision for NumericReasoner (seed 4c6b962047ed).
final class D0954NumericReasonerTests: XCTestCase {
    private let seed = "4c6b962047ed"
    func testCacheKeyCollision_rng() {
        var rng = Phase2RNG(seed: seed)
        let q1 = rng.randomQuery(length: 2)
        let k1 = Phase2Techniques.cacheKey(query: q1 + "  ", container: "mnemo")
        let k2 = Phase2Techniques.cacheKey(query: q1, container: "mnemo")
        XCTAssertEqual(k1, k2)
        XCTAssertTrue(Phase2Techniques.cacheKeysDistinct([(q1, "mnemo"), (q1 + " other", "mnemo")]))
    }

}
