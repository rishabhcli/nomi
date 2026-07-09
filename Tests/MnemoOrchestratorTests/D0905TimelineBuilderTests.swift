import XCTest
@testable import MnemoOrchestrator

/// D-0905: cache poisoning resistance for TimelineBuilder (seed 786ebf36c505).
final class D0905TimelineBuilderTests: XCTestCase {
    private let seed = "786ebf36c505"
    func testCachePoisoning_rng() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("mnemo::\0evil"))
        XCTAssertFalse(Phase2Techniques.cachePoisonKeyRejected(Phase2Techniques.cacheKey(query: "safe", container: "mnemo")))
    }

}
