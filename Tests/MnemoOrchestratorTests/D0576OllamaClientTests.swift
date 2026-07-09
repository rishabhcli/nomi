import XCTest
@testable import MnemoOrchestrator

/// D-0576: subprocess stderr backpressure for OllamaClient (seed 7adf8c976e39).
final class D0576OllamaClientTests: XCTestCase {
    private let seed = "7adf8c976e39"

    func testSubprocess_drainsStderr() {
        XCTAssertTrue(OllamaClient.drainsSubprocessStderr())
    }

    func testSubprocess_phase2DrainRequired() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 50))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

    func testSubprocess_asyncCancelSafe() async {
        XCTAssertTrue(await OllamaClient.asyncStreamCancelProof())
        XCTAssertTrue(OllamaClient.asyncStreamCancelSafe())
    }
}
