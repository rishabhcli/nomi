import XCTest
@testable import MnemoOrchestrator

/// D-0685: cache poisoning resistance for Consolidation (seed 4192adce3719).
final class D0685ConsolidationTests: XCTestCase {
    private let seed = "4192adce3719"

    func testCache_resistsPoisonKeys() {
        XCTAssertFalse(Consolidation.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(Consolidation.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse(Consolidation.resistsCachePoisoning("\0injected"))
    }

    func testCache_phase2PoisonRejected() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\0bad"))
    }

    func testCache_keySeparatesContainer() {
        let k1 = Consolidation.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = Consolidation.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }
}
