import XCTest
@testable import MnemoOrchestrator

/// D-0177: Inspector AsyncStream cancellation (seed 5b2f88d78201).
final class D0177InspectorTests: XCTestCase {
    private let seed = "5b2f88d78201"

    func testAsyncStreamCancelsCleanly() async {
        let task = Task {
            await Inspector.asyncStreamCancelProof()
        }
        task.cancel()
        _ = await task.value
        XCTAssertTrue(Inspector.asyncStreamCancelSafe())
    }
}
