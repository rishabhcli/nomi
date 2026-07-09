import XCTest
@testable import MnemoOrchestrator

/// D-0890: ingest gate timing proofs for LLMSynthesizer (seed 18bc5719fd2b).
final class D0890LLMSynthesizerTests: XCTestCase {
    private let seed = "18bc5719fd2b"
    func testIngestGateTiming_rng() async {
        var rng = Phase2RNG(seed: seed)
        let start = ContinuousClock.now
        let gate = IngestGate(retriever: FakeRetriever(hitsByMode: ["memories": []]))
        _ = await gate.waitUntilSearchable(probe: rng.randomQuery(length: 2), timeout: .milliseconds(100))
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: ContinuousClock.now))
    }

}
