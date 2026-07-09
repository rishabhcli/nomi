import XCTest
@testable import MnemoOrchestrator

/// D-0570: ingest gate timing proofs for CharSpan (seed b41621d76796).
final class D0570CharSpanTests: XCTestCase {
    private let seed = "b41621d76796"

    func testIngestGate_timingMonotonic() async {
        XCTAssertTrue(await CharSpan.ingestGateTimingProof(timeoutMs: 2))
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
