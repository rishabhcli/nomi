import XCTest
@testable import MnemoOrchestrator

/// D-0170: IngestGate ingest gate timing proofs (seed 6e7491367a0e).
final class D0170IngestGateTests: XCTestCase {
    private let seed = "6e7491367a0e"

    func testIngestGateTimingProof() async {
        let ok = await IngestGate.ingestGateTimingProof(timeoutMs: 5)
        XCTAssertFalse(ok)
    }
}
