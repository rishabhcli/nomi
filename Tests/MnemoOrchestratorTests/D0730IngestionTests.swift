import XCTest
@testable import MnemoOrchestrator

/// D-0730: ingest gate timing proofs for Ingestion (seed 2b60c7370d2f).
final class D0730IngestionTests: XCTestCase {
    private let seed = "2b60c7370d2f"

    func testIngestGate_timingMonotonic() async {
        XCTAssertTrue(await Ingestion.ingestGateTimingProof(timeoutMs: 2))
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
