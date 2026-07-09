import XCTest
@testable import MnemoOrchestrator

/// D-0652: numeric synthesis distractor immunity for FollowUp (seed e206719cbcd2).
final class D0652FollowUpTests: XCTestCase {
    private let seed = "e206719cbcd2"

    func testNumeric_rejectsDistractor() {
        XCTAssertTrue(FollowUp.rejectsNumericDistractor("budget 50000 in 2020", question: "what year?"))
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
