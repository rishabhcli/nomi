import XCTest
@testable import MnemoOrchestrator

/// D-0057: EngineIntegration AsyncStream cancellation (seed 83f0b9def60f).
final class D0057EngineIntegrationTests: XCTestCase {
    private let seed = "83f0b9def60f"

    func testAsyncStreamCancelsCleanly() async {
        let task = Task {
            await EngineIntegration.asyncStreamCancelProof()
        }
        task.cancel()
        _ = await task.value
        XCTAssertTrue(EngineIntegration.asyncStreamCancelSafe())
    }
}
