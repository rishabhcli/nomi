import XCTest
@testable import MnemoOrchestrator

/// D-0785: cache poisoning resistance for MemoryDynamics (seed 44f3b6af80a9).
final class D0785MemoryDynamicsTests: XCTestCase {
    private let seed = "44f3b6af80a9"
    func testCachePoisoning_rng() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("mnemo::\0evil"))
        XCTAssertFalse(Phase2Techniques.cachePoisonKeyRejected(Phase2Techniques.cacheKey(query: "safe", container: "mnemo")))
    }

}
