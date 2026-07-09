import XCTest
@testable import MnemoOrchestrator

/// D-0197: EntityExtractor AsyncStream cancellation (seed 2c033b6439ff).
final class D0197EntityExtractorTests: XCTestCase {
    private let seed = "2c033b6439ff"

    func testAsyncStreamCancelsCleanly() async {
        let task = Task {
            await EntityExtractor.asyncStreamCancelProof()
        }
        task.cancel()
        _ = await task.value
        XCTAssertTrue(EntityExtractor.asyncStreamCancelSafe())
    }
}
