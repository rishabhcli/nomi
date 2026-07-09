import XCTest
@testable import MnemoOrchestrator

/// D-0717: AsyncStream cancellation for RouterEscalator (seed 54b27ddf5d7c).
final class D0717RouterEscalatorTests: XCTestCase {
    private let seed = "54b27ddf5d7c"

    func testAsync_cancelProof() async {
        XCTAssertTrue(await RouterEscalator.asyncStreamCancelProof())
    }

    func testAsync_cancelSafe() {
        XCTAssertTrue(RouterEscalator.asyncStreamCancelSafe())
    }

    func testAsync_phase2CancelledBeforeFinish() {
        XCTAssertTrue(Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true))
        XCTAssertFalse(Phase2Techniques.streamCancelledBeforeFinish(true, cancelled: false))
    }
}
