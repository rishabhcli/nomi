import XCTest
@testable import MnemoOrchestrator

/// D-0648: citation verifier false-positive elimination for NumericReasoner (seed 736514b95fd6).
final class D0648NumericReasonerTests: XCTestCase {
    private let seed = "736514b95fd6"

    func testCitation_parenthesesPreserved() {
        let claim = "Revenue grew (down from 842) per notes."
        XCTAssertTrue(claim.contains("("))
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(
            sentence: claim, evidence: Phase2TestSupport.sampleEvidence))
    }

    func testCitation_notTrivialFragment() {
        XCTAssertFalse(NumericReasoner.isTrivialFragment("User prefers Bazel for builds."))
    }

    func testCitation_groundingCheck() {
        Phase2TestSupport.assertCitationGrounding(GroundingCheck.citationIntegritySupported)
    }
}
