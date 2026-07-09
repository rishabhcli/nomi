import XCTest
@testable import MnemoOrchestrator

/// D-0645: cache poisoning resistance for AnswerCache (seed 139dd0ca8d01).
final class D0645AnswerCacheTests: XCTestCase {
    private let seed = "139dd0ca8d01"

    func testCache_resistsPoisonKeys() {
        XCTAssertFalse(AnswerCache.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(AnswerCache.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse(AnswerCache.resistsCachePoisoning("\0injected"))
    }

    func testCache_phase2PoisonRejected() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\0bad"))
    }

    func testCache_keySeparatesContainer() {
        let k1 = AnswerCache.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = AnswerCache.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }
}
