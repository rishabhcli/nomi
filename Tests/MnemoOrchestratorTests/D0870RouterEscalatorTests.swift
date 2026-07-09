import XCTest
@testable import MnemoOrchestrator

/// D-0870: ingest gate timing proofs for RouterEscalator (seed 4f793c104955).
final class D0870RouterEscalatorTests: XCTestCase {
    private let seed = "4f793c104955"
    func testIngestGateTiming_rng() async {
        var rng = Phase2RNG(seed: seed)
        let start = ContinuousClock.now
        let gate = IngestGate(retriever: FakeRetriever(hitsByMode: ["memories": []]))
        _ = await gate.waitUntilSearchable(probe: rng.randomQuery(length: 2), timeout: .milliseconds(100))
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: ContinuousClock.now))
    }

}
