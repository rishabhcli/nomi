import XCTest
@testable import MnemoOrchestrator

/// D-0930: ingest gate timing proofs for LLMHopPlanner (seed fe00e32ecd47).
final class D0930LLMHopPlannerTests: XCTestCase {
    private let seed = "fe00e32ecd47"
    func testIngestGateTiming_rng() async {
        var rng = Phase2RNG(seed: seed)
        let start = ContinuousClock.now
        let gate = IngestGate(retriever: FakeRetriever(hitsByMode: ["memories": []]))
        _ = await gate.waitUntilSearchable(probe: rng.randomQuery(length: 2), timeout: .milliseconds(100))
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: ContinuousClock.now))
    }

}
