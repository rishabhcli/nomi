import XCTest
@testable import MnemoOrchestrator

/// D-0565: cache poisoning resistance for EvidenceGathering (seed 4e73cd934d6e).
final class D0565EvidenceGatheringTests: XCTestCase {
    private let seed = "4e73cd934d6e"

    func testCache_resistsPoisonKeys() {
        XCTAssertFalse(EvidenceGathering.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(EvidenceGathering.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse(EvidenceGathering.resistsCachePoisoning("\0injected"))
    }

    func testCache_phase2PoisonRejected() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\0bad"))
    }

    func testCache_keySeparatesContainer() {
        let k1 = EvidenceGathering.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = EvidenceGathering.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }
}
