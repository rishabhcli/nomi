import XCTest
@testable import MnemoOrchestrator

/// D-0768: citation verifier false-positive elimination for RouterEscalator (seed 34e9321df97e).
final class D0768RouterEscalatorTests: XCTestCase {
    private let seed = "34e9321df97e"
    func testCitationFalsePositive_rng() {
        let evidence = [Retrieved(memory: "revenue down from 842 to 100", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(sentence: "Revenue fell (down from 842).", evidence: evidence))
    }

}
