import XCTest
@testable import MnemoOrchestrator

/// D-0965: cache poisoning resistance for Digest (seed 7737444a31bb).
final class D0965DigestTests: XCTestCase {
    private let seed = "7737444a31bb"
    func testCachePoisoning_rng() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("mnemo::\0evil"))
        XCTAssertFalse(Phase2Techniques.cachePoisonKeyRejected(Phase2Techniques.cacheKey(query: "safe", container: "mnemo")))
    }

}
