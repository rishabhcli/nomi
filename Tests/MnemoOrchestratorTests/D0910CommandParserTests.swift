import XCTest
@testable import MnemoOrchestrator

/// D-0910: ingest gate timing proofs for CommandParser (seed add75c1b93ff).
final class D0910CommandParserTests: XCTestCase {
    private let seed = "add75c1b93ff"
    func testIngestGateTiming_rng() async {
        var rng = Phase2RNG(seed: seed)
        let start = ContinuousClock.now
        let gate = IngestGate(retriever: FakeRetriever(hitsByMode: ["memories": []]))
        _ = await gate.waitUntilSearchable(probe: rng.randomQuery(length: 2), timeout: .milliseconds(100))
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: ContinuousClock.now))
    }

}
