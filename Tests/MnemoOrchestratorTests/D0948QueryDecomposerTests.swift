import XCTest
@testable import MnemoOrchestrator

/// D-0948: citation verifier false-positive elimination for QueryDecomposer (seed bd803ff9627d).
final class D0948QueryDecomposerTests: XCTestCase {
    private let seed = "bd803ff9627d"
    func testCitationFalsePositive_rng() {
        let evidence = [Retrieved(memory: "revenue down from 842 to 100", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(sentence: "Revenue fell (down from 842).", evidence: evidence))
    }

}
