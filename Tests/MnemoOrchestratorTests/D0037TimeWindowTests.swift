import XCTest
@testable import MnemoOrchestrator

/// D-0037: TimeWindow AsyncStream cancellation (seed bd4765f0860b).
final class D0037TimeWindowTests: XCTestCase {
    private let seed = "bd4765f0860b"

    func testAsyncStreamCancelsCleanly() async {
        let task = Task {
            await TimeWindow.asyncStreamCancelProof()
        }
        task.cancel()
        _ = await task.value
        XCTAssertTrue(TimeWindow.asyncStreamCancelSafe())
    }
}
