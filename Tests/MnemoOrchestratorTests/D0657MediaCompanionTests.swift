import XCTest
@testable import MnemoOrchestrator

/// D-0657: AsyncStream cancellation for MediaCompanion (seed acbf4c21af53).
final class D0657MediaCompanionTests: XCTestCase {
    private let seed = "acbf4c21af53"

    func testAsync_cancelProof() async {
        XCTAssertTrue(await MediaCompanion.asyncStreamCancelProof())
    }

    func testAsync_cancelSafe() {
        XCTAssertTrue(MediaCompanion.asyncStreamCancelSafe())
    }

    func testAsync_phase2CancelledBeforeFinish() {
        XCTAssertTrue(Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true))
        XCTAssertFalse(Phase2Techniques.streamCancelledBeforeFinish(true, cancelled: false))
    }
}
