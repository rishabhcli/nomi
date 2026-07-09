import XCTest
@testable import MnemoOrchestrator

/// D-0805: cache poisoning resistance for FollowUp (seed 583e553605bc).
final class D0805FollowUpTests: XCTestCase {
    private let seed = "583e553605bc"
    func testCachePoisoning_rng() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("mnemo::\0evil"))
        XCTAssertFalse(Phase2Techniques.cachePoisonKeyRejected(Phase2Techniques.cacheKey(query: "safe", container: "mnemo")))
    }

}
