import XCTest
@testable import MnemoOrchestrator

/// D-0908: citation verifier false-positive elimination for Confidence (seed fe773fcf0488).
final class D0908ConfidenceTests: XCTestCase {
    private let seed = "fe773fcf0488"
    func testCitationFalsePositive_rng() {
        let evidence = [Retrieved(memory: "revenue down from 842 to 100", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(sentence: "Revenue fell (down from 842).", evidence: evidence))
    }

}
