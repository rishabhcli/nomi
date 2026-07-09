import XCTest
@testable import MnemoOrchestrator

/// D-0925: cache poisoning resistance for CitationVerifier (seed c06c7c49008c).
final class D0925CitationVerifierTests: XCTestCase {
    private let seed = "c06c7c49008c"
    func testCachePoisoning_rng() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("mnemo::\0evil"))
        XCTAssertFalse(Phase2Techniques.cachePoisonKeyRejected(Phase2Techniques.cacheKey(query: "safe", container: "mnemo")))
    }

}
