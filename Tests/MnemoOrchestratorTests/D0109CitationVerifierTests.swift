import XCTest
@testable import MnemoOrchestrator

/// D-0109: CitationVerifier memory supersession race conditions (seed b2c81e2b411b).
final class D0109CitationVerifierTests: XCTestCase {
    private let seed = "b2c81e2b411b"

    func testSupersessionRaceSafe() {
        let k1 = CitationVerifier.supersessionKey(id: "a", version: 1)
        let k2 = CitationVerifier.supersessionKey(id: "a", version: 2)
        XCTAssertNotEqual(k1, k2)
        XCTAssertTrue(CitationVerifier.supersessionRaceSafe())
    }
}
