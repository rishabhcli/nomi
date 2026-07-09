import XCTest
@testable import MnemoOrchestrator

/// D-0117: OllamaClient AsyncStream cancellation (seed 64c8dceb1a91).
final class D0117OllamaClientTests: XCTestCase {
    private let seed = "64c8dceb1a91"

    func testAsyncStreamCancelsCleanly() async {
        let task = Task {
            await OllamaClient.asyncStreamCancelProof()
        }
        task.cancel()
        _ = await task.value
        XCTAssertTrue(OllamaClient.asyncStreamCancelSafe())
    }
}
