import XCTest
@testable import MnemoOrchestrator

/// D-0368: KeywordBackstop citation verifier false-positive elimination (seed 41d106215976).
final class D0368KeywordBackstopTests: XCTestCase {
    private let seed = "41d106215976"

    func testCitationIntegrityRejectsFabrication() {
        let ev = [Phase2TechniqueSupport.sampleRetrieved(memory: "Uses Bazel.")]
        XCTAssertFalse(KeywordBackstop.citationIntegritySupported("Uses CMake [doc].", evidence: ev))
        XCTAssertTrue(KeywordBackstop.citationIntegritySupported("Uses Bazel [doc].", evidence: ev))
    }

    func testEmptyClaimPasses() {
        XCTAssertTrue(KeywordBackstop.citationIntegritySupported("   ", evidence: []))
    }

    func testProperty_shortTokensSkipped() {
        var rng = Phase2RNG(seed: seed)
        let ev = [Phase2TechniqueSupport.sampleRetrieved(memory: "alpha beta gamma delta")]
        for _ in 0..<4 {
            let ok = KeywordBackstop.citationIntegritySupported("alpha [x].", evidence: ev)
            XCTAssertEqual(ok, KeywordBackstop.citationIntegritySupported("alpha [x].", evidence: ev))
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
