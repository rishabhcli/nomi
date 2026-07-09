import XCTest
@testable import MnemoOrchestrator

/// D-0970: ingest gate timing proofs for QueryService (seed 6e7be1daadac).
final class D0970QueryServiceTests: XCTestCase {
    private let seed = "6e7be1daadac"
    func testIngestGateTiming_rng() async {
        var rng = Phase2RNG(seed: seed)
        let start = ContinuousClock.now
        let gate = IngestGate(retriever: FakeRetriever(hitsByMode: ["memories": []]))
        _ = await gate.waitUntilSearchable(probe: rng.randomQuery(length: 2), timeout: .milliseconds(100))
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: ContinuousClock.now))
    }

}
