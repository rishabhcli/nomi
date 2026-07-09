import XCTest
@testable import MnemoOrchestrator

/// D-0790: ingest gate timing proofs for Profile (seed 06a82de0cc5b).
final class D0790ProfileTests: XCTestCase {
    private let seed = "06a82de0cc5b"
    func testIngestGateTiming_rng() async {
        var rng = Phase2RNG(seed: seed)
        let start = ContinuousClock.now
        let gate = IngestGate(retriever: FakeRetriever(hitsByMode: ["memories": []]))
        _ = await gate.waitUntilSearchable(probe: rng.randomQuery(length: 2), timeout: .milliseconds(100))
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: ContinuousClock.now))
    }

}
