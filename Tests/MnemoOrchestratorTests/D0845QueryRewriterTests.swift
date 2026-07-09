import XCTest
@testable import MnemoOrchestrator

/// D-0845: cache poisoning resistance for QueryRewriter (seed 47d33ebdbef0).
final class D0845QueryRewriterTests: XCTestCase {
    private let seed = "47d33ebdbef0"
    func testCachePoisoning_rng() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("mnemo::\0evil"))
        XCTAssertFalse(Phase2Techniques.cachePoisonKeyRejected(Phase2Techniques.cacheKey(query: "safe", container: "mnemo")))
    }

}
