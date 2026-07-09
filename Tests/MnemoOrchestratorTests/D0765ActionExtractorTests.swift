import XCTest
@testable import MnemoOrchestrator

/// D-0765: cache poisoning resistance for ActionExtractor (seed b4a9715a0406).
final class D0765ActionExtractorTests: XCTestCase {
    private let seed = "b4a9715a0406"
    func testCachePoisoning_rng() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("mnemo::\0evil"))
        XCTAssertFalse(Phase2Techniques.cachePoisonKeyRejected(Phase2Techniques.cacheKey(query: "safe", container: "mnemo")))
    }

}
