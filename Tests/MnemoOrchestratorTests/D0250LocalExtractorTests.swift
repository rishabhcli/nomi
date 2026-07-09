import XCTest
@testable import MnemoOrchestrator

/// D-0250: LocalExtractor ingest gate timing proofs (seed e94e26653bd7).
final class D0250LocalExtractorTests: XCTestCase {
    private let seed = "e94e26653bd7"

    func testIngestGateTimingProof() async {
        let ok = await LocalExtractor.ingestGateTimingProof(timeoutMs: 5)
        XCTAssertFalse(ok)
    }
}
