import XCTest
@testable import MnemoOrchestrator

/// D-0828: citation verifier false-positive elimination for LLMHopPlanner (seed c1746e7a41c9).
final class D0828LLMHopPlannerTests: XCTestCase {
    private let seed = "c1746e7a41c9"
    func testCitationFalsePositive_rng() {
        let evidence = [Retrieved(memory: "revenue down from 842 to 100", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(sentence: "Revenue fell (down from 842).", evidence: evidence))
    }

}
