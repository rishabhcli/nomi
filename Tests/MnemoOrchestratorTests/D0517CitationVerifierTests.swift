import XCTest
@testable import MnemoOrchestrator

/// D-0517: AsyncStream cancellation for CitationVerifier (seed aa12750dce2a).
final class D0517CitationVerifierTests: XCTestCase {
    private let seed = "aa12750dce2a"

    func testAsync_cancelProof() async {
        XCTAssertTrue(await CitationVerifier.asyncStreamCancelProof())
    }

    func testAsync_cancelSafe() {
        XCTAssertTrue(CitationVerifier.asyncStreamCancelSafe())
    }

    func testAsync_phase2CancelledBeforeFinish() {
        XCTAssertTrue(Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true))
        XCTAssertFalse(Phase2Techniques.streamCancelledBeforeFinish(true, cancelled: false))
    }
}
