import XCTest
@testable import MnemoOrchestrator

/// D-0616: subprocess stderr backpressure for EvidenceGathering (seed b17df63f191a).
final class D0616EvidenceGatheringTests: XCTestCase {
    private let seed = "b17df63f191a"

    func testSubprocess_drainsStderr() {
        XCTAssertTrue(EvidenceGathering.drainsSubprocessStderr())
    }

    func testSubprocess_phase2DrainRequired() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 50))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

    func testSubprocess_asyncCancelSafe() async {
        XCTAssertTrue(await EvidenceGathering.asyncStreamCancelProof())
        XCTAssertTrue(EvidenceGathering.asyncStreamCancelSafe())
    }
}
