import XCTest
@testable import MnemoOrchestrator

/// D-0585: cache poisoning resistance for Inspector (seed 8f29ec960137).
final class D0585InspectorTests: XCTestCase {
    private let seed = "8f29ec960137"

    func testCache_resistsPoisonKeys() {
        XCTAssertFalse(Inspector.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(Inspector.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse(Inspector.resistsCachePoisoning("\0injected"))
    }

    func testCache_phase2PoisonRejected() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\0bad"))
    }

    func testCache_keySeparatesContainer() {
        let k1 = Inspector.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = Inspector.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }
}
