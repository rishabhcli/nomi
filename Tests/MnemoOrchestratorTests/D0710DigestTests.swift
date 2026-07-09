import XCTest
@testable import MnemoOrchestrator

/// D-0710: ingest gate timing proofs for Digest (seed 5bd0ada69aa7).
final class D0710DigestTests: XCTestCase {
    private let seed = "5bd0ada69aa7"

    func testIngestGate_timingMonotonic() async {
        XCTAssertTrue(await Digest.ingestGateTimingProof(timeoutMs: 2))
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
