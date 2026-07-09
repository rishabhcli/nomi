import XCTest
@testable import MnemoOrchestrator

/// D-0230: EgressGuard ingest gate timing proofs (seed 8ac5429df2fc).
final class D0230EgressGuardTests: XCTestCase {
    private let seed = "8ac5429df2fc"

    func testIngestGateTimingProof() async {
        let ok = await EgressGuard.ingestGateTimingProof(timeoutMs: 5)
        XCTAssertFalse(ok)
    }
}
