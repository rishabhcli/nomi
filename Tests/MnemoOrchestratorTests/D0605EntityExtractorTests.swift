import XCTest
@testable import MnemoOrchestrator

/// D-0605: cache poisoning resistance for EntityExtractor (seed c8ca0bdcb173).
final class D0605EntityExtractorTests: XCTestCase {
    private let seed = "c8ca0bdcb173"

    func testCache_resistsPoisonKeys() {
        XCTAssertFalse(EntityExtractor.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(EntityExtractor.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse(EntityExtractor.resistsCachePoisoning("\0injected"))
    }

    func testCache_phase2PoisonRejected() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\0bad"))
    }

    func testCache_keySeparatesContainer() {
        let k1 = EntityExtractor.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = EntityExtractor.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }

    func testEntities_extractsMidSentence() {
        let ents = EntityExtractor.entities(in: "Notes mention Rust often.")
        XCTAssertTrue(ents.contains("Rust"))
    }
}
