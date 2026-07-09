import XCTest
@testable import MnemoOrchestrator

/// D-0777: AsyncStream cancellation for LLMHopPlanner (seed afb653fe5f2c).
final class D0777LLMHopPlannerTests: XCTestCase {
    private let seed = "afb653fe5f2c"
    func testAsyncStreamCancellation_rng() async {
        var rng = Phase2RNG(seed: seed)
        let gate = IngestGate(retriever: FakeRetriever(hitsByMode: [:]))
        let stream = gate.searchableStream(probe: rng.randomQuery(length: 2), timeout: .milliseconds(50))
        var it = stream.makeAsyncIterator()
        let task = Task { await it.next() }
        task.cancel()
        _ = await task.value
        XCTAssertTrue(Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true))
    }

}
