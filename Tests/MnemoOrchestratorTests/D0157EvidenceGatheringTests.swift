import XCTest
@testable import MnemoOrchestrator

/// D-0157: EvidenceGathering AsyncStream cancellation (seed 2a61c75139b6).
final class D0157EvidenceGatheringTests: XCTestCase {
    private let seed = "2a61c75139b6"

    func testAsyncStreamCancelsCleanly() async {
        let task = Task {
            await EvidenceGathering.asyncStreamCancelProof()
        }
        task.cancel()
        _ = await task.value
        XCTAssertTrue(EvidenceGathering.asyncStreamCancelSafe())
    }
}
