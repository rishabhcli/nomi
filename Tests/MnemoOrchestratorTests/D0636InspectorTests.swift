import XCTest
@testable import MnemoOrchestrator

/// D-0636: subprocess stderr backpressure for Inspector (seed 341517f037ce).
final class D0636InspectorTests: XCTestCase {
    private let seed = "341517f037ce"

    func testSubprocess_drainsStderr() {
        XCTAssertTrue(Inspector.drainsSubprocessStderr())
    }

    func testSubprocess_phase2DrainRequired() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 50))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

    func testSubprocess_asyncCancelSafe() async {
        XCTAssertTrue(await Inspector.asyncStreamCancelProof())
        XCTAssertTrue(Inspector.asyncStreamCancelSafe())
    }
}
