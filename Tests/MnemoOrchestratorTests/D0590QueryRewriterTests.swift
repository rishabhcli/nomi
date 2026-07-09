import XCTest
@testable import MnemoOrchestrator

/// D-0590: ingest gate timing proofs for QueryRewriter (seed e386b25cce81).
final class D0590QueryRewriterTests: XCTestCase {
    private let seed = "e386b25cce81"

    func testIngestGate_timingMonotonic() async {
        XCTAssertTrue(await QueryRewriter.ingestGateTimingProof(timeoutMs: 2))
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
