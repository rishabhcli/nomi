import XCTest
@testable import MnemoOrchestrator

/// D-0137: PersonalRanker AsyncStream cancellation (seed b2bc5cda511c).
final class D0137PersonalRankerTests: XCTestCase {
    private let seed = "b2bc5cda511c"

    func testAsyncStreamCancelsCleanly() async {
        let task = Task {
            await PersonalRanker.asyncStreamCancelProof()
        }
        task.cancel()
        _ = await task.value
        XCTAssertTrue(PersonalRanker.asyncStreamCancelSafe())
    }
}
