import XCTest
@testable import MnemoOrchestrator

/// D-0505: cache poisoning resistance for LocalExtractor (seed 613351460ed7).
final class D0505LocalExtractorTests: XCTestCase {
    private let seed = "613351460ed7"

    func testCache_resistsPoisonKeys() {
        XCTAssertFalse(LocalExtractor.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(LocalExtractor.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse(LocalExtractor.resistsCachePoisoning("\0injected"))
    }

    func testCache_phase2PoisonRejected() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\0bad"))
    }

    func testCache_keySeparatesContainer() {
        let k1 = LocalExtractor.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = LocalExtractor.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }
}
