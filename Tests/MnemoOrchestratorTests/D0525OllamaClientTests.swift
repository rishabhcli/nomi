import XCTest
@testable import MnemoOrchestrator

/// D-0525: cache poisoning resistance for OllamaClient (seed af20903d9092).
final class D0525OllamaClientTests: XCTestCase {
    private let seed = "af20903d9092"

    func testCache_resistsPoisonKeys() {
        XCTAssertFalse(OllamaClient.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(OllamaClient.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse(OllamaClient.resistsCachePoisoning("\0injected"))
    }

    func testCache_phase2PoisonRejected() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\0bad"))
    }

    func testCache_keySeparatesContainer() {
        let k1 = OllamaClient.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = OllamaClient.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }
}
