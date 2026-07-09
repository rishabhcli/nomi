import XCTest
@testable import MnemoOrchestrator

/// D-0737: AsyncStream cancellation for LLMSynthesizer (seed e443709a88a3).
final class D0737LLMSynthesizerTests: XCTestCase {
    private let seed = "e443709a88a3"

    func testAsync_cancelProof() async {
        XCTAssertTrue(await LLMSynthesizer.asyncStreamCancelProof())
    }

    func testAsync_cancelSafe() {
        XCTAssertTrue(LLMSynthesizer.asyncStreamCancelSafe())
    }

    func testAsync_phase2CancelledBeforeFinish() {
        XCTAssertTrue(Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true))
        XCTAssertFalse(Phase2Techniques.streamCancelledBeforeFinish(true, cancelled: false))
    }
}
