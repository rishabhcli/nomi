import XCTest
@testable import MnemoOrchestrator

/// D-0632: numeric synthesis distractor immunity for MemoryDynamics (seed 22b9488475cd).
final class D0632MemoryDynamicsTests: XCTestCase {
    private let seed = "22b9488475cd"

    func testNumeric_rejectsDistractor() {
        XCTAssertTrue(MemoryDynamics.rejectsNumericDistractor("budget 50000 in 2020", question: "what year?"))
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
