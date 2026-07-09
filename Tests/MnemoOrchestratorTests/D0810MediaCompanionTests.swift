import XCTest
@testable import MnemoOrchestrator

/// D-0810: ingest gate timing proofs for MediaCompanion (seed 20745a981f83).
final class D0810MediaCompanionTests: XCTestCase {
    private let seed = "20745a981f83"
    func testIngestGateTiming_rng() async {
        var rng = Phase2RNG(seed: seed)
        let start = ContinuousClock.now
        let gate = IngestGate(retriever: FakeRetriever(hitsByMode: ["memories": []]))
        _ = await gate.waitUntilSearchable(probe: rng.randomQuery(length: 2), timeout: .milliseconds(100))
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: ContinuousClock.now))
    }

}
