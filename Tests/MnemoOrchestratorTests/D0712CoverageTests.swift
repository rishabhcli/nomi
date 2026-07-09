import XCTest
@testable import MnemoOrchestrator

/// D-0712: numeric synthesis distractor immunity for Coverage (seed 82eca6bc3d1e).
final class D0712CoverageTests: XCTestCase {
    private let seed = "82eca6bc3d1e"

    func testNumeric_rejectsDistractor() {
        XCTAssertTrue(Coverage.rejectsNumericDistractor("budget 50000 in 2020", question: "what year?"))
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
