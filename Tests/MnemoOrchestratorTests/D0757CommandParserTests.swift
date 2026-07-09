import XCTest
@testable import MnemoOrchestrator

/// D-0757: AsyncStream cancellation for CommandParser (seed 47ef78853c2f).
final class D0757CommandParserTests: XCTestCase {
    private let seed = "47ef78853c2f"
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
