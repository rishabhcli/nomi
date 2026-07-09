import XCTest
@testable import MnemoOrchestrator

/// D-0597: AsyncStream cancellation for NumericReasoner (seed 0998ebfa2997).
final class D0597NumericReasonerTests: XCTestCase {
    private let seed = "0998ebfa2997"

    func testAsync_cancelProof() async {
        XCTAssertTrue(await NumericReasoner.asyncStreamCancelProof())
    }

    func testAsync_cancelSafe() {
        XCTAssertTrue(NumericReasoner.asyncStreamCancelSafe())
    }

    func testAsync_phase2CancelledBeforeFinish() {
        XCTAssertTrue(Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true))
        XCTAssertFalse(Phase2Techniques.streamCancelledBeforeFinish(true, cancelled: false))
    }
}
