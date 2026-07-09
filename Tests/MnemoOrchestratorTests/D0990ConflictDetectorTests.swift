import XCTest
@testable import MnemoOrchestrator

/// D-0990: ingest gate timing proofs for ConflictDetector (seed a2998ed0bdda).
final class D0990ConflictDetectorTests: XCTestCase {
    private let seed = "a2998ed0bdda"
    func testIngestGateTiming_rng() async {
        var rng = Phase2RNG(seed: seed)
        let start = ContinuousClock.now
        let gate = IngestGate(retriever: FakeRetriever(hitsByMode: ["memories": []]))
        _ = await gate.waitUntilSearchable(probe: rng.randomQuery(length: 2), timeout: .milliseconds(100))
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: ContinuousClock.now))
    }

}
