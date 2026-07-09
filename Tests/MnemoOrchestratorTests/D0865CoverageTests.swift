import XCTest
@testable import MnemoOrchestrator

/// D-0865: cache poisoning resistance for Coverage (seed bb388aca8dce).
final class D0865CoverageTests: XCTestCase {
    private let seed = "bb388aca8dce"
    func testCachePoisoning_rng() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("mnemo::\0evil"))
        XCTAssertFalse(Phase2Techniques.cachePoisonKeyRejected(Phase2Techniques.cacheKey(query: "safe", container: "mnemo")))
    }

}
