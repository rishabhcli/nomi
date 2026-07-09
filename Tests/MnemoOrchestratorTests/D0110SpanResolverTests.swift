import XCTest
@testable import MnemoOrchestrator

/// D-0110: SpanResolver ingest gate timing proofs (seed 92cb6fb3a89f).
final class D0110SpanResolverTests: XCTestCase {
    private let seed = "92cb6fb3a89f"

    func testIngestGateTimingProof() async {
        let ok = await SpanResolver.ingestGateTimingProof(timeoutMs: 5)
        XCTAssertFalse(ok)
    }
}
