import XCTest
@testable import MnemoOrchestrator

/// D-0556: subprocess stderr backpressure for LocalExtractor (seed 247356b8214d).
final class D0556LocalExtractorTests: XCTestCase {
    private let seed = "247356b8214d"

    func testSubprocess_drainsStderr() {
        XCTAssertTrue(LocalExtractor.drainsSubprocessStderr())
    }

    func testSubprocess_phase2DrainRequired() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 50))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

    func testSubprocess_asyncCancelSafe() async {
        XCTAssertTrue(await LocalExtractor.asyncStreamCancelProof())
        XCTAssertTrue(LocalExtractor.asyncStreamCancelSafe())
    }
}
