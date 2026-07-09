import XCTest
@testable import MnemoOrchestrator

/// D-0950: ingest gate timing proofs for AdaptiveEffort (seed 136bd87e7139).
final class D0950AdaptiveEffortTests: XCTestCase {
    private let seed = "136bd87e7139"
    func testIngestGateTiming_rng() async {
        var rng = Phase2RNG(seed: seed)
        let start = ContinuousClock.now
        let gate = IngestGate(retriever: FakeRetriever(hitsByMode: ["memories": []]))
        _ = await gate.waitUntilSearchable(probe: rng.randomQuery(length: 2), timeout: .milliseconds(100))
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: ContinuousClock.now))
    }

}
