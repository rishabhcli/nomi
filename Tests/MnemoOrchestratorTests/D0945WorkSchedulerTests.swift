import XCTest
@testable import MnemoOrchestrator

/// D-0945: cache poisoning resistance for WorkScheduler (seed f4c917f4ca60).
final class D0945WorkSchedulerTests: XCTestCase {
    private let seed = "f4c917f4ca60"
    func testCachePoisoning_rng() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("mnemo::\0evil"))
        XCTAssertFalse(Phase2Techniques.cachePoisonKeyRejected(Phase2Techniques.cacheKey(query: "safe", container: "mnemo")))
    }

}
