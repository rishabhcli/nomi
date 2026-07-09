import XCTest
@testable import MnemoOrchestrator

/// D-0690: ingest gate timing proofs for WorkScheduler (seed 1e9d72628f81).
final class D0690WorkSchedulerTests: XCTestCase {
    private let seed = "1e9d72628f81"

    func testIngestGate_timingMonotonic() async {
        XCTAssertTrue(await WorkScheduler.ingestGateTimingProof(timeoutMs: 2))
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
