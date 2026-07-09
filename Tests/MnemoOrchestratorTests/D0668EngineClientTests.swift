import XCTest
@testable import MnemoOrchestrator

/// D-0668: citation verifier false-positive elimination for EngineClient (seed 12feef84259c).
final class D0668EngineClientTests: XCTestCase {
    private let seed = "12feef84259c"

    func testCitation_parenthesesPreserved() {
        let claim = "Revenue grew (down from 842) per notes."
        XCTAssertTrue(claim.contains("("))
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(
            sentence: claim, evidence: Phase2TestSupport.sampleEvidence))
    }

    func testCitation_notTrivialFragment() {
        XCTAssertFalse(EngineClient.isTrivialFragment("User prefers Bazel for builds."))
    }

    func testCitation_groundingCheck() {
        Phase2TestSupport.assertCitationGrounding(GroundingCheck.citationIntegritySupported)
    }
}
