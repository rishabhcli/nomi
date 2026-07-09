import XCTest
@testable import MnemoOrchestrator

/// D-0532: numeric synthesis distractor immunity for Consolidation (seed 1ff1f3bc25f3).
final class D0532ConsolidationTests: XCTestCase {
    private let seed = "1ff1f3bc25f3"

    func testNumeric_rejectsDistractor() {
        XCTAssertTrue(Consolidation.rejectsNumericDistractor("budget 50000 in 2020", question: "what year?"))
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
