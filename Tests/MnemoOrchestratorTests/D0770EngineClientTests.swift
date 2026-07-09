import XCTest
@testable import MnemoOrchestrator

/// D-0770: ingest gate timing proofs for EngineClient (seed ce91bf51b782).
final class D0770EngineClientTests: XCTestCase {
    private let seed = "ce91bf51b782"
    func testIngestGateTiming_rng() async {
        var rng = Phase2RNG(seed: seed)
        let start = ContinuousClock.now
        let gate = IngestGate(retriever: FakeRetriever(hitsByMode: ["memories": []]))
        _ = await gate.waitUntilSearchable(probe: rng.randomQuery(length: 2), timeout: .milliseconds(100))
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: ContinuousClock.now))
    }

}
