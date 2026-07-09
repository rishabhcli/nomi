import XCTest
@testable import MnemoOrchestrator

/// D-0732: numeric synthesis distractor immunity for SyncEngine (seed 7b525a45a345).
final class D0732SyncEngineTests: XCTestCase {
    private let seed = "7b525a45a345"

    func testNumeric_rejectsDistractor() {
        XCTAssertTrue(SyncEngine.rejectsNumericDistractor("budget 50000 in 2020", question: "what year?"))
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
