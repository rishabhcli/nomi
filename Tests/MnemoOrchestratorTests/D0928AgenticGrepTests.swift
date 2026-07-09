import XCTest
@testable import MnemoOrchestrator

/// D-0928: citation verifier false-positive elimination for AgenticGrep (seed 1bfbf02b9b9b).
final class D0928AgenticGrepTests: XCTestCase {
    private let seed = "1bfbf02b9b9b"
    func testCitationFalsePositive_rng() {
        let evidence = [Retrieved(memory: "revenue down from 842 to 100", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(sentence: "Revenue fell (down from 842).", evidence: evidence))
    }

}
