import XCTest
@testable import MnemoOrchestrator

/// D-0516: subprocess stderr backpressure for EngineIntegration (seed c03c1932654f).
final class D0516EngineIntegrationTests: XCTestCase {
    private let seed = "c03c1932654f"

    func testSubprocess_drainsStderr() {
        XCTAssertTrue(EngineIntegration.drainsSubprocessStderr())
    }

    func testSubprocess_phase2DrainRequired() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 50))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

    func testSubprocess_asyncCancelSafe() async {
        XCTAssertTrue(await EngineIntegration.asyncStreamCancelProof())
        XCTAssertTrue(EngineIntegration.asyncStreamCancelSafe())
    }
}
