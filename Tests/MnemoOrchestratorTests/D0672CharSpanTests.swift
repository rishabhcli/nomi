import XCTest
@testable import MnemoOrchestrator

/// D-0672: numeric synthesis distractor immunity for CharSpan (seed 4f89ecc26aea).
final class D0672CharSpanTests: XCTestCase {
    private let seed = "4f89ecc26aea"

    func testNumeric_rejectsDistractor() {
        XCTAssertTrue(CharSpan.rejectsNumericDistractor("budget 50000 in 2020", question: "what year?"))
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
