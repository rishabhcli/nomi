import XCTest
@testable import MnemoOrchestrator

/// D-0885: cache poisoning resistance for SyncEngine (seed 65b958eea59b).
final class D0885SyncEngineTests: XCTestCase {
    private let seed = "65b958eea59b"
    func testCachePoisoning_rng() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("mnemo::\0evil"))
        XCTAssertFalse(Phase2Techniques.cachePoisonKeyRejected(Phase2Techniques.cacheKey(query: "safe", container: "mnemo")))
    }

}
