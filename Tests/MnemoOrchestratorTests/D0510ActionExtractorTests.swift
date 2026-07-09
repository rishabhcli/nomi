import XCTest
@testable import MnemoOrchestrator

/// D-0510: ingest gate timing proofs for ActionExtractor (seed ccfa50d7e120).
final class D0510ActionExtractorTests: XCTestCase {
    private let seed = "ccfa50d7e120"

    func testIngestGate_timingMonotonic() async {
        XCTAssertTrue(await ActionExtractor.ingestGateTimingProof(timeoutMs: 2))
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
