import XCTest
@testable import MnemoOrchestrator

/// D-0537: AsyncStream cancellation for WorkScheduler (seed d2dceb2ffa3a).
final class D0537WorkSchedulerTests: XCTestCase {
    private let seed = "d2dceb2ffa3a"

    func testAsync_cancelProof() async {
        XCTAssertTrue(await WorkScheduler.asyncStreamCancelProof())
    }

    func testAsync_cancelSafe() {
        XCTAssertTrue(WorkScheduler.asyncStreamCancelSafe())
    }

    func testAsync_phase2CancelledBeforeFinish() {
        XCTAssertTrue(Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true))
        XCTAssertFalse(Phase2Techniques.streamCancelledBeforeFinish(true, cancelled: false))
    }
}
