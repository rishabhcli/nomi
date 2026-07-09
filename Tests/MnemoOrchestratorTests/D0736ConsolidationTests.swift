import XCTest
@testable import MnemoOrchestrator

/// D-0736: subprocess stderr backpressure for Consolidation (seed e811ce12b647).
final class D0736ConsolidationTests: XCTestCase {
    private let seed = "e811ce12b647"

    func testSubprocess_drainsStderr() {
        XCTAssertTrue(Consolidation.drainsSubprocessStderr())
    }

    func testSubprocess_phase2DrainRequired() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 50))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

    func testSubprocess_asyncCancelSafe() async {
        XCTAssertTrue(await Consolidation.asyncStreamCancelProof())
        XCTAssertTrue(Consolidation.asyncStreamCancelSafe())
    }
}
