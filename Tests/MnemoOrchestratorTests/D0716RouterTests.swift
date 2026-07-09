import XCTest
@testable import MnemoOrchestrator

/// D-0716: subprocess stderr backpressure for Router (seed 348fa49c4b83).
final class D0716RouterTests: XCTestCase {
    private let seed = "348fa49c4b83"

    func testSubprocess_drainsStderr() {
        XCTAssertTrue(Router.drainsSubprocessStderr())
    }

    func testSubprocess_phase2DrainRequired() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 50))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

    func testSubprocess_asyncCancelSafe() async {
        XCTAssertTrue(await Router.asyncStreamCancelProof())
        XCTAssertTrue(Router.asyncStreamCancelSafe())
    }
}
