import XCTest
@testable import MnemoOrchestrator

/// D-0985: cache poisoning resistance for Ingestion (seed 12089796f289).
final class D0985IngestionTests: XCTestCase {
    private let seed = "12089796f289"
    func testCachePoisoning_rng() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("mnemo::\0evil"))
        XCTAssertFalse(Phase2Techniques.cachePoisonKeyRejected(Phase2Techniques.cacheKey(query: "safe", container: "mnemo")))
    }

}
