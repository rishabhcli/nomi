import XCTest
@testable import MnemoOrchestrator

/// D-0725: cache poisoning resistance for KeywordBackstop (seed 69c2b3c4b808).
final class D0725KeywordBackstopTests: XCTestCase {
    private let seed = "69c2b3c4b808"

    func testCache_resistsPoisonKeys() {
        XCTAssertFalse(KeywordBackstop.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(KeywordBackstop.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse(KeywordBackstop.resistsCachePoisoning("\0injected"))
    }

    func testCache_phase2PoisonRejected() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\0bad"))
    }

    func testCache_keySeparatesContainer() {
        let k1 = KeywordBackstop.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = KeywordBackstop.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }
}
