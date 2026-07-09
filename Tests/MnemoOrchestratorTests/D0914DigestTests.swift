import XCTest
@testable import MnemoOrchestrator

/// D-0914: answer cache key collision for Digest (seed b4a6b39cf091).
final class D0914DigestTests: XCTestCase {
    private let seed = "b4a6b39cf091"
    func testCacheKeyCollision_rng() {
        var rng = Phase2RNG(seed: seed)
        let q1 = rng.randomQuery(length: 2)
        let k1 = Phase2Techniques.cacheKey(query: q1 + "  ", container: "mnemo")
        let k2 = Phase2Techniques.cacheKey(query: q1, container: "mnemo")
        XCTAssertEqual(k1, k2)
        XCTAssertTrue(Phase2Techniques.cacheKeysDistinct([(q1, "mnemo"), (q1 + " other", "mnemo")]))
    }

}
