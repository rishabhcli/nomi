import XCTest
@testable import MnemoOrchestrator

/// D-0988: citation verifier false-positive elimination for ContentHash (seed d5bbe8f62d24).
final class D0988ContentHashTests: XCTestCase {
    private let seed = "d5bbe8f62d24"
    func testCitationFalsePositive_rng() {
        let evidence = [Retrieved(memory: "revenue down from 842 to 100", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(sentence: "Revenue fell (down from 842).", evidence: evidence))
    }

}
