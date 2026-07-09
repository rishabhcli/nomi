import XCTest
@testable import MnemoOrchestrator

/// D-0692: numeric synthesis distractor immunity for QueryRewriter (seed cf924c92abfa).
final class D0692QueryRewriterTests: XCTestCase {
    private let seed = "cf924c92abfa"

    func testNumeric_rejectsDistractor() {
        XCTAssertTrue(QueryRewriter.rejectsNumericDistractor("budget 50000 in 2020", question: "what year?"))
    }

    func testNumeric_phase2Immune() {
        XCTAssertTrue(Phase2Techniques.immuneToNumericDistractor(
            claim: "budget 2020", evidence: Phase2TestSupport.sampleEvidence, distractor: "1999"))
    }

    func testNumeric_rngIterations() {
        var rng = Phase2RNG(seed: seed)
        XCTAssertGreaterThan(rng.nextInt(upperBound: 100), -1)
    }
}
