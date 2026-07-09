import XCTest
@testable import MnemoOrchestrator

/// D-0030: QueryDecomposer ingest gate timing proofs (seed db9b5a72948b).
final class D0030QueryDecomposerTests: XCTestCase {
    private let seed = "db9b5a72948b"

    func testIngestGateTimingProof() async {
        let ok = await QueryDecomposer.ingestGateTimingProof(timeoutMs: 5)
        XCTAssertFalse(ok)
    }
}
