import XCTest
@testable import MnemoOrchestrator

/// D-0676: subprocess stderr backpressure for ContextAssembler (seed 457f856d2df0).
final class D0676ContextAssemblerTests: XCTestCase {
    private let seed = "457f856d2df0"

    func testSubprocess_drainsStderr() {
        XCTAssertTrue(ContextAssembler.drainsSubprocessStderr())
    }

    func testSubprocess_phase2DrainRequired() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 50))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

    func testSubprocess_asyncCancelSafe() async {
        XCTAssertTrue(await ContextAssembler.asyncStreamCancelProof())
        XCTAssertTrue(ContextAssembler.asyncStreamCancelSafe())
    }
}
