import XCTest
@testable import MnemoOrchestrator

/// D-0557: AsyncStream cancellation for Digest (seed adc2aacfdd4b).
final class D0557DigestTests: XCTestCase {
    private let seed = "adc2aacfdd4b"

    func testAsync_cancelProof() async {
        XCTAssertTrue(await Digest.asyncStreamCancelProof())
    }

    func testAsync_cancelSafe() {
        XCTAssertTrue(Digest.asyncStreamCancelSafe())
    }

    func testAsync_phase2CancelledBeforeFinish() {
        XCTAssertTrue(Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true))
        XCTAssertFalse(Phase2Techniques.streamCancelledBeforeFinish(true, cancelled: false))
    }
}
