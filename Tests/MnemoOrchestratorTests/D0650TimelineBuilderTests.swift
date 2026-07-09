import XCTest
@testable import MnemoOrchestrator

/// D-0650: ingest gate timing proofs for TimelineBuilder (seed 7a85f2be2236).
final class D0650TimelineBuilderTests: XCTestCase {
    private let seed = "7a85f2be2236"

    func testIngestGate_timingMonotonic() async {
        XCTAssertTrue(await TimelineBuilder.ingestGateTimingProof(timeoutMs: 2))
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
