import XCTest
@testable import MnemoOrchestrator

/// D-0617: AsyncStream cancellation for EngineClient (seed 6d2583e16ccb).
final class D0617EngineClientTests: XCTestCase {
    private let seed = "6d2583e16ccb"

    func testAsync_cancelProof() async {
        XCTAssertTrue(await EngineClient.asyncStreamCancelProof())
    }

    func testAsync_cancelSafe() {
        XCTAssertTrue(EngineClient.asyncStreamCancelSafe())
    }

    func testAsync_phase2CancelledBeforeFinish() {
        XCTAssertTrue(Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true))
        XCTAssertFalse(Phase2Techniques.streamCancelledBeforeFinish(true, cancelled: false))
    }
}
