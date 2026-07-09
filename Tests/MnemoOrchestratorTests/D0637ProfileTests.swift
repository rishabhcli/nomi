import XCTest
@testable import MnemoOrchestrator

/// D-0637: AsyncStream cancellation for Profile (seed cbea4525304d).
final class D0637ProfileTests: XCTestCase {
    private let seed = "cbea4525304d"

    func testAsync_cancelProof() async {
        XCTAssertTrue(await Profile.asyncStreamCancelProof())
    }

    func testAsync_cancelSafe() {
        XCTAssertTrue(Profile.asyncStreamCancelSafe())
    }

    func testAsync_phase2CancelledBeforeFinish() {
        XCTAssertTrue(Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true))
        XCTAssertFalse(Phase2Techniques.streamCancelledBeforeFinish(true, cancelled: false))
    }
}
