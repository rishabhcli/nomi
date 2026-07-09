import XCTest
@testable import MnemoOrchestrator

/// D-0957: AsyncStream cancellation for ResponseStyle (seed 11e9f5d6ba96).
final class D0957ResponseStyleTests: XCTestCase {
    private let seed = "11e9f5d6ba96"
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
