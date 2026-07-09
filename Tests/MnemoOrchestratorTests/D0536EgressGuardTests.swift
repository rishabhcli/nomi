import XCTest
@testable import MnemoOrchestrator

/// D-0536: subprocess stderr backpressure for EgressGuard (seed 25fd11e2e0cd).
final class D0536EgressGuardTests: XCTestCase {
    private let seed = "25fd11e2e0cd"

    func testSubprocess_drainsStderr() {
        XCTAssertTrue(EgressGuard.drainsSubprocessStderr())
    }

    func testSubprocess_phase2DrainRequired() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 50))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

    func testSubprocess_asyncCancelSafe() async {
        XCTAssertTrue(await EgressGuard.asyncStreamCancelProof())
        XCTAssertTrue(EgressGuard.asyncStreamCancelSafe())
    }
}
