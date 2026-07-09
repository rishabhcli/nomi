import XCTest
@testable import MnemoOrchestrator

/// D-0888: citation verifier false-positive elimination for ConflictDetector (seed 4bd0dfa47d4c).
final class D0888ConflictDetectorTests: XCTestCase {
    private let seed = "4bd0dfa47d4c"
    func testCitationFalsePositive_rng() {
        let evidence = [Retrieved(memory: "revenue down from 842 to 100", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(sentence: "Revenue fell (down from 842).", evidence: evidence))
    }

}
