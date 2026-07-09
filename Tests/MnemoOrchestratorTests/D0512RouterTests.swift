import XCTest
@testable import MnemoOrchestrator

/// D-0512: numeric synthesis distractor immunity for Router (seed f84ec9321351).
final class D0512RouterTests: XCTestCase {
    private let seed = "f84ec9321351"

    func testNumeric_rejectsDistractor() {
        XCTAssertTrue(Router.rejectsNumericDistractor("budget 50000 in 2020", question: "what year?"))
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
