import XCTest
@testable import MnemoOrchestrator

/// D-0190: TimeWindow ingest gate timing proofs (seed 4303aa63cad6).
final class D0190TimeWindowTests: XCTestCase {
    private let seed = "4303aa63cad6"

    func testIngestGateTimingProof() async {
        let ok = await TimeWindow.ingestGateTimingProof(timeoutMs: 5)
        XCTAssertFalse(ok)
    }
}
