import XCTest
@testable import MnemoOrchestrator

/// D-0077: EgressGuard AsyncStream cancellation (seed dfce1ca8bd4b).
final class D0077EgressGuardTests: XCTestCase {
    private let seed = "dfce1ca8bd4b"

    func testAsyncStreamCancelsCleanly() async {
        let task = Task {
            await EgressGuard.asyncStreamCancelProof()
        }
        task.cancel()
        _ = await task.value
        XCTAssertTrue(EgressGuard.asyncStreamCancelSafe())
    }
}
