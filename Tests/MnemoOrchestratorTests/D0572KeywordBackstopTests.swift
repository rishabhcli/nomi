import XCTest
@testable import MnemoOrchestrator

/// D-0572: numeric synthesis distractor immunity for KeywordBackstop (seed ef89a19e356a).
final class D0572KeywordBackstopTests: XCTestCase {
    private let seed = "ef89a19e356a"

    func testNumeric_rejectsDistractor() {
        XCTAssertTrue(KeywordBackstop.rejectsNumericDistractor("budget 50000 in 2020", question: "what year?"))
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
