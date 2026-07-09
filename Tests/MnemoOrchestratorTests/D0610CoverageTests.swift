import XCTest
@testable import MnemoOrchestrator

/// D-0610: ingest gate timing proofs for Coverage (seed 327d41966e7b).
final class D0610CoverageTests: XCTestCase {
    private let seed = "327d41966e7b"

    func testIngestGate_timingMonotonic() async {
        XCTAssertTrue(await Coverage.ingestGateTimingProof(timeoutMs: 2))
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
