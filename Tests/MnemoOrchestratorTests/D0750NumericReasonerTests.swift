import XCTest
@testable import MnemoOrchestrator

/// D-0750: ingest gate timing proofs for NumericReasoner (seed 15f08098c6b6).
final class D0750NumericReasonerTests: XCTestCase {
    private let seed = "15f08098c6b6"

    func testIngestGate_timingMonotonic() async {
        XCTAssertTrue(await NumericReasoner.ingestGateTimingProof(timeoutMs: 2))
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
