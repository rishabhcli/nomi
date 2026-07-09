import XCTest
@testable import MnemoOrchestrator

/// D-0850: ingest gate timing proofs for QueryHistory (seed 5d46dab101f5).
final class D0850QueryHistoryTests: XCTestCase {
    private let seed = "5d46dab101f5"
    func testIngestGateTiming_rng() async {
        var rng = Phase2RNG(seed: seed)
        let start = ContinuousClock.now
        let gate = IngestGate(retriever: FakeRetriever(hitsByMode: ["memories": []]))
        _ = await gate.waitUntilSearchable(probe: rng.randomQuery(length: 2), timeout: .milliseconds(100))
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: ContinuousClock.now))
    }

}
