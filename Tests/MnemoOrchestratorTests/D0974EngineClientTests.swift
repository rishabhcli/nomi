import XCTest
@testable import MnemoOrchestrator

/// D-0974: answer cache key collision for EngineClient (seed 2c294e3bec58).
final class D0974EngineClientTests: XCTestCase {
    private let seed = "2c294e3bec58"
    func testCacheKeyCollision_rng() {
        var rng = Phase2RNG(seed: seed)
        let q1 = rng.randomQuery(length: 2)
        let k1 = Phase2Techniques.cacheKey(query: q1 + "  ", container: "mnemo")
        let k2 = Phase2Techniques.cacheKey(query: q1, container: "mnemo")
        XCTAssertEqual(k1, k2)
        XCTAssertTrue(Phase2Techniques.cacheKeysDistinct([(q1, "mnemo"), (q1 + " other", "mnemo")]))
    }

}
