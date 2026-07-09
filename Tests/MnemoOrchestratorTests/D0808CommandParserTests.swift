import XCTest
@testable import MnemoOrchestrator

/// D-0808: citation verifier false-positive elimination for CommandParser (seed 0a3572ae628e).
final class D0808CommandParserTests: XCTestCase {
    private let seed = "0a3572ae628e"
    func testCitationFalsePositive_rng() {
        let evidence = [Retrieved(memory: "revenue down from 842 to 100", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(sentence: "Revenue fell (down from 842).", evidence: evidence))
    }

}
