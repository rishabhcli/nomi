import XCTest
@testable import MnemoOrchestrator

/// D-0208: EvidenceGathering citation verifier false-positive elimination (seed b4b478a4ca20).
final class D0208EvidenceGatheringTests: XCTestCase {
    private let seed = "b4b478a4ca20"

    func testEliminatesCitationFalsePositives() {
        XCTAssertTrue(EvidenceGathering.isTrivialFragment("Ok."))
        XCTAssertFalse(EvidenceGathering.isTrivialFragment("Bazel is the build system."))
    }
}
