import XCTest
@testable import MnemoOrchestrator

/// D-0670: ingest gate timing proofs for CitationVerifier (seed c879979ef6ec).
final class D0670CitationVerifierTests: XCTestCase {
    private let seed = "c879979ef6ec"

    func testIngestGate_timingMonotonic() async {
        XCTAssertTrue(await CitationVerifier.ingestGateTimingProof(timeoutMs: 2))
    }

    func testIngestGate_phase2Monotonic() {
        let start = ContinuousClock.now
        let end = start
        XCTAssertTrue(Phase2Techniques.ingestGateTimingMonotonic(start: start, end: end))
    }

    func testIngestGate_indexingTerminal() {
        let t = EngineClient.indexingTerminalState(path: "/tmp/x.md")
        XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
    }
}
