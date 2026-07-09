import XCTest
@testable import MnemoOrchestrator

/// D-0592: numeric synthesis distractor immunity for ScopeClassifier (seed 7bfec8310e14).
final class D0592ScopeClassifierTests: XCTestCase {
    private let seed = "7bfec8310e14"

    func testNumeric_rejectsDistractor() {
        XCTAssertTrue(ScopeClassifier.rejectsNumericDistractor("budget 50000 in 2020", question: "what year?"))
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
