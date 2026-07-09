import XCTest
@testable import MnemoOrchestrator

/// D-0665: cache poisoning resistance for Router (seed 586596f47410).
final class D0665RouterTests: XCTestCase {
    private let seed = "586596f47410"

    func testCache_resistsPoisonKeys() {
        XCTAssertFalse(Router.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(Router.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse(Router.resistsCachePoisoning("\0injected"))
    }

    func testCache_phase2PoisonRejected() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\0bad"))
    }

    func testCache_keySeparatesContainer() {
        let k1 = Router.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = Router.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }
}
