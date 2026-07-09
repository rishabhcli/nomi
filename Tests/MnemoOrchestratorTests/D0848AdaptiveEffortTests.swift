import XCTest
@testable import MnemoOrchestrator

/// D-0848: citation verifier false-positive elimination for AdaptiveEffort (seed bd81bb8607d8).
final class D0848AdaptiveEffortTests: XCTestCase {
    private let seed = "bd81bb8607d8"
    func testCitationFalsePositive_rng() {
        let evidence = [Retrieved(memory: "revenue down from 842 to 100", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(sentence: "Revenue fell (down from 842).", evidence: evidence))
    }

}
