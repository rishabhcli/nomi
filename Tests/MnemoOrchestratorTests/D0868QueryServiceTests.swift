import XCTest
@testable import MnemoOrchestrator

/// D-0868: citation verifier false-positive elimination for QueryService (seed 45e70ffa9b79).
final class D0868QueryServiceTests: XCTestCase {
    private let seed = "45e70ffa9b79"
    func testCitationFalsePositive_rng() {
        let evidence = [Retrieved(memory: "revenue down from 842 to 100", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(sentence: "Revenue fell (down from 842).", evidence: evidence))
    }

}
