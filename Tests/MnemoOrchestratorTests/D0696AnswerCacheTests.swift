import XCTest
@testable import MnemoOrchestrator

/// D-0696: subprocess stderr backpressure for AnswerCache (seed dae13ec4a3f2).
final class D0696AnswerCacheTests: XCTestCase {
    private let seed = "dae13ec4a3f2"

    func testSubprocess_drainsStderr() {
        XCTAssertTrue(AnswerCache.drainsSubprocessStderr())
    }

    func testSubprocess_phase2DrainRequired() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 50))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

    func testSubprocess_asyncCancelSafe() async {
        XCTAssertTrue(await AnswerCache.asyncStreamCancelProof())
        XCTAssertTrue(AnswerCache.asyncStreamCancelSafe())
    }
}
