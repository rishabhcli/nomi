import XCTest
@testable import MnemoOrchestrator

/// D-0550: ingest gate timing proofs for FollowUp (seed 7193fb23dc19).
final class D0550FollowUpTests: XCTestCase {
    private let seed = "7193fb23dc19"

    func testIngestGate_timingMonotonic() async {
        XCTAssertTrue(await FollowUp.ingestGateTimingProof(timeoutMs: 2))
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
