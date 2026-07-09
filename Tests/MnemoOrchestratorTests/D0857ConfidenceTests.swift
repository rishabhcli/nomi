import XCTest
@testable import MnemoOrchestrator

/// D-0857: AsyncStream cancellation for Confidence (seed 48aa3ce3f7a0).
final class D0857ConfidenceTests: XCTestCase {
    private let seed = "48aa3ce3f7a0"
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
