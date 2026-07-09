import XCTest
@testable import MnemoOrchestrator

/// D-0090: ResponseStyle ingest gate timing proofs (seed 28b70cfdf982).
final class D0090ResponseStyleTests: XCTestCase {
    private let seed = "28b70cfdf982"

    func testIngestGateTimingProof() async {
        let ok = await ResponseStyle.ingestGateTimingProof(timeoutMs: 5)
        XCTAssertFalse(ok)
    }
}
