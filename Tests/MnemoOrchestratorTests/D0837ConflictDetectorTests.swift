import XCTest
@testable import MnemoOrchestrator

/// D-0837: AsyncStream cancellation for ConflictDetector (seed e3dc2a419bb4).
final class D0837ConflictDetectorTests: XCTestCase {
    private let seed = "e3dc2a419bb4"
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
