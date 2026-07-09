import XCTest
@testable import MnemoOrchestrator

/// D-0697: AsyncStream cancellation for QueryHistory (seed 8e06dcb81019).
final class D0697QueryHistoryTests: XCTestCase {
    private let seed = "8e06dcb81019"

    func testAsync_cancelProof() async {
        XCTAssertTrue(await QueryHistory.asyncStreamCancelProof())
    }

    func testAsync_cancelSafe() {
        XCTAssertTrue(QueryHistory.asyncStreamCancelSafe())
    }

    func testAsync_phase2CancelledBeforeFinish() {
        XCTAssertTrue(Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true))
        XCTAssertFalse(Phase2Techniques.streamCancelledBeforeFinish(true, cancelled: false))
    }
}
