import XCTest
@testable import MnemoOrchestrator

/// D-0596: subprocess stderr backpressure for PersonalRanker (seed 57c2add5c98c).
final class D0596PersonalRankerTests: XCTestCase {
    private let seed = "57c2add5c98c"

    func testSubprocess_drainsStderr() {
        XCTAssertTrue(PersonalRanker.drainsSubprocessStderr())
    }

    func testSubprocess_phase2DrainRequired() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 50))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

    func testSubprocess_asyncCancelSafe() async {
        XCTAssertTrue(await PersonalRanker.asyncStreamCancelProof())
        XCTAssertTrue(PersonalRanker.asyncStreamCancelSafe())
    }
}
