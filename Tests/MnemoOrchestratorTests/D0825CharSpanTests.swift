import XCTest
@testable import MnemoOrchestrator

/// D-0825: cache poisoning resistance for CharSpan (seed edfce891486b).
final class D0825CharSpanTests: XCTestCase {
    private let seed = "edfce891486b"
    func testCachePoisoning_rng() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("mnemo::\0evil"))
        XCTAssertFalse(Phase2Techniques.cachePoisonKeyRejected(Phase2Techniques.cacheKey(query: "safe", container: "mnemo")))
    }

}
