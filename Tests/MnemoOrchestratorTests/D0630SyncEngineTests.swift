import XCTest
@testable import MnemoOrchestrator

/// D-0630: ingest gate timing proofs for SyncEngine (seed 4ff69fa08f53).
final class D0630SyncEngineTests: XCTestCase {
    private let seed = "4ff69fa08f53"

    func testIngestGate_timingMonotonic() async {
        XCTAssertTrue(await SyncEngine.ingestGateTimingProof(timeoutMs: 2))
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
