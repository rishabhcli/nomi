import XCTest
@testable import MnemoOrchestrator

/// D-0097: LocalExtractor AsyncStream cancellation (seed 5ee26c46d9f6).
final class D0097LocalExtractorTests: XCTestCase {
    private let seed = "5ee26c46d9f6"

    func testAsyncStreamCancelsCleanly() async {
        let task = Task {
            await LocalExtractor.asyncStreamCancelProof()
        }
        task.cancel()
        _ = await task.value
        XCTAssertTrue(LocalExtractor.asyncStreamCancelSafe())
    }
}
