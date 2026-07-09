import XCTest
@testable import MnemoOrchestrator

/// D-0968: citation verifier false-positive elimination for Highlight (seed 9a186d12fced).
final class D0968HighlightTests: XCTestCase {
    private let seed = "9a186d12fced"
    func testCitationFalsePositive_rng() {
        let evidence = [Retrieved(memory: "revenue down from 842 to 100", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(sentence: "Revenue fell (down from 842).", evidence: evidence))
    }

}
