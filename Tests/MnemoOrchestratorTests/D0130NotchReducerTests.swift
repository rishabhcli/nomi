import XCTest
@testable import MnemoOrchestrator

/// D-0130: NotchReducer ingest gate timing proofs (seed dd501825e3bc).
final class D0130NotchReducerTests: XCTestCase {
    private let seed = "dd501825e3bc"

    func testIngestGateTimingProof() async {
        let ok = await NotchReducer.ingestGateTimingProof(timeoutMs: 5)
        XCTAssertFalse(ok)
    }
}
