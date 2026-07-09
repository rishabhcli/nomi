import XCTest
@testable import MnemoOrchestrator

/// D-0545: cache poisoning resistance for PersonalRanker (seed 17f40f739461).
final class D0545PersonalRankerTests: XCTestCase {
    private let seed = "17f40f739461"

    func testCache_resistsPoisonKeys() {
        XCTAssertFalse(PersonalRanker.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(PersonalRanker.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse(PersonalRanker.resistsCachePoisoning("\0injected"))
    }

    func testCache_phase2PoisonRejected() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\0bad"))
    }

    func testCache_keySeparatesContainer() {
        let k1 = PersonalRanker.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = PersonalRanker.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }
}
