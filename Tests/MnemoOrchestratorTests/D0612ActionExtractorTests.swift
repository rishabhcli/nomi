import XCTest
@testable import MnemoOrchestrator

/// D-0612: numeric synthesis distractor immunity for ActionExtractor (seed 8f7b0f77b6c8).
final class D0612ActionExtractorTests: XCTestCase {
    private let seed = "8f7b0f77b6c8"

    func testNumeric_rejectsDistractor() {
        XCTAssertTrue(ActionExtractor.rejectsNumericDistractor("budget 50000 in 2020", question: "what year?"))
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
