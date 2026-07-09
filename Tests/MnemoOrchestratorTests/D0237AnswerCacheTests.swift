import XCTest
@testable import MnemoOrchestrator

/// D-0237: AnswerCache AsyncStream cancellation (seed 6f80ef5e9c16).
final class D0237AnswerCacheTests: XCTestCase {
    private let seed = "6f80ef5e9c16"

    func testAsyncStreamCancelsCleanly() async {
        let task = Task {
            await AnswerCache.asyncStreamCancelProof()
        }
        task.cancel()
        _ = await task.value
        XCTAssertTrue(AnswerCache.asyncStreamCancelSafe())
    }
}
