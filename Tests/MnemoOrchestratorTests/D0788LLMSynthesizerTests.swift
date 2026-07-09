import XCTest
@testable import MnemoOrchestrator

/// D-0788: citation verifier false-positive elimination for LLMSynthesizer (seed 9c27cc1ac3fd).
final class D0788LLMSynthesizerTests: XCTestCase {
    private let seed = "9c27cc1ac3fd"
    func testCitationFalsePositive_rng() {
        let evidence = [Retrieved(memory: "revenue down from 842 to 100", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(sentence: "Revenue fell (down from 842).", evidence: evidence))
    }

}
