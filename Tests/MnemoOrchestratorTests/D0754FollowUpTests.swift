import XCTest
@testable import MnemoOrchestrator

/// D-0754: answer cache key collision for FollowUp (seed e0b49d67b2c6).
final class D0754FollowUpTests: XCTestCase {
    private let seed = "e0b49d67b2c6"
    func testCacheKeyCollision_rng() {
        var rng = Phase2RNG(seed: seed)
        let q1 = rng.randomQuery(length: 2)
        let k1 = Phase2Techniques.cacheKey(query: q1 + "  ", container: "mnemo")
        let k2 = Phase2Techniques.cacheKey(query: q1, container: "mnemo")
        XCTAssertEqual(k1, k2)
        XCTAssertTrue(Phase2Techniques.cacheKeysDistinct([(q1, "mnemo"), (q1 + " other", "mnemo")]))
    }

}
