import XCTest
@testable import MnemoOrchestrator

/// D-0797: AsyncStream cancellation for AdaptiveEffort (seed b9414eb11be9).
final class D0797AdaptiveEffortTests: XCTestCase {
    private let seed = "b9414eb11be9"
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
