import XCTest
@testable import MnemoOrchestrator

/// D-0150: Preferences ingest gate timing proofs (seed a08075f9cd43).
final class D0150PreferencesTests: XCTestCase {
    private let seed = "a08075f9cd43"

    func testIngestGateTimingProof() async {
        let ok = await Preferences.ingestGateTimingProof(timeoutMs: 5)
        XCTAssertFalse(ok)
    }
}
