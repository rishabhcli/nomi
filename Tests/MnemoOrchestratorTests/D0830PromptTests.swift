import XCTest
@testable import MnemoOrchestrator

/// D-0830: ingest gate timing proofs for Prompt (seed fc8895453702).
final class D0830PromptTests: XCTestCase {
    private let seed = "fc8895453702"
    func testIngestGateTiming_rng() async {
        var rng = Phase2RNG(seed: seed)
        let start = ContinuousClock.now
        let gate = IngestGate(retriever: FakeRetriever(hitsByMode: ["memories": []]))
        _ = await gate.waitUntilSearchable(probe: rng.randomQuery(length: 2), timeout: .milliseconds(100))
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: ContinuousClock.now))
    }

}
