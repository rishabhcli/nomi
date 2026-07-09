import XCTest
@testable import MnemoOrchestrator

/// D-0217: ContextAssembler AsyncStream cancellation (seed 14671a7bf194).
final class D0217ContextAssemblerTests: XCTestCase {
    private let seed = "14671a7bf194"

    func testAsyncStreamCancelsCleanly() async {
        let task = Task {
            await ContextAssembler.asyncStreamCancelProof()
        }
        task.cancel()
        _ = await task.value
        XCTAssertTrue(ContextAssembler.asyncStreamCancelSafe())
    }
}
