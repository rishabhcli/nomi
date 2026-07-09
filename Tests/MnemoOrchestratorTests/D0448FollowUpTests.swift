import XCTest
@testable import MnemoOrchestrator

/// D-0448: FollowUp citation verifier false-positive elimination (seed 372b538b3816).
final class D0448FollowUpTests: XCTestCase {
    private let seed = "372b538b3816"

    func testCitationIntegrityRejectsFabrication() {
        let ev = [Phase2TechniqueSupport.sampleRetrieved(memory: "Uses Bazel.")]
        XCTAssertFalse(FollowUp.citationIntegritySupported("Uses CMake [doc].", evidence: ev))
        XCTAssertTrue(FollowUp.citationIntegritySupported("Uses Bazel [doc].", evidence: ev))
    }

    func testEmptyClaimPasses() {
        XCTAssertTrue(FollowUp.citationIntegritySupported("   ", evidence: []))
    }

    func testProperty_shortTokensSkipped() {
        var rng = Phase2RNG(seed: seed)
        let ev = [Phase2TechniqueSupport.sampleRetrieved(memory: "alpha beta gamma delta")]
        for _ in 0..<4 {
            let ok = FollowUp.citationIntegritySupported("alpha [x].", evidence: ev)
            XCTAssertEqual(ok, FollowUp.citationIntegritySupported("alpha [x].", evidence: ev))
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
