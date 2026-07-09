import XCTest
@testable import MnemoOrchestrator

/// D-0210: EngineIntegration ingest gate timing proofs (seed a92a762349d8).
final class D0210EngineIntegrationTests: XCTestCase {
    private let seed = "a92a762349d8"

    func testIngestGateTimingProof() async {
        let ok = await EngineIntegration.ingestGateTimingProof(timeoutMs: 5)
        XCTAssertFalse(ok)
    }
}
