import XCTest
@testable import MnemoOrchestrator

/// D-0677: AsyncStream cancellation for Prompt (seed d924da9dee55).
final class D0677PromptTests: XCTestCase {
    private let seed = "d924da9dee55"

    func testAsync_cancelProof() async {
        XCTAssertTrue(await Prompt.asyncStreamCancelProof())
    }

    func testAsync_cancelSafe() {
        XCTAssertTrue(Prompt.asyncStreamCancelSafe())
    }

    func testAsync_phase2CancelledBeforeFinish() {
        XCTAssertTrue(Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true))
        XCTAssertFalse(Phase2Techniques.streamCancelledBeforeFinish(true, cancelled: false))
    }
}
