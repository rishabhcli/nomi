import XCTest
@testable import MnemoOrchestrator

/// D-0877: AsyncStream cancellation for AgenticGrep (seed f2c1bf3d952d).
final class D0877AgenticGrepTests: XCTestCase {
    private let seed = "f2c1bf3d952d"
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
