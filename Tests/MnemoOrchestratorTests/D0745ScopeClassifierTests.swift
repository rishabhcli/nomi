import XCTest
@testable import MnemoOrchestrator

/// D-0745: cache poisoning resistance for ScopeClassifier (seed 242b60144fc4).
final class D0745ScopeClassifierTests: XCTestCase {
    private let seed = "242b60144fc4"

    func testCache_resistsPoisonKeys() {
        XCTAssertFalse(ScopeClassifier.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(ScopeClassifier.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse(ScopeClassifier.resistsCachePoisoning("\0injected"))
    }

    func testCache_phase2PoisonRejected() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\0bad"))
    }

    func testCache_keySeparatesContainer() {
        let k1 = ScopeClassifier.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = ScopeClassifier.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }
}
