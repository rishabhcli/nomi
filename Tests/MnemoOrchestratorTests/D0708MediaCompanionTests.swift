import XCTest
@testable import MnemoOrchestrator

/// D-0708: citation verifier false-positive elimination for MediaCompanion (seed eef3ef76bfa2).
final class D0708MediaCompanionTests: XCTestCase {
    private let seed = "eef3ef76bfa2"

    func testCitation_parenthesesPreserved() {
        let claim = "Revenue grew (down from 842) per notes."
        XCTAssertTrue(claim.contains("("))
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(
            sentence: claim, evidence: Phase2TestSupport.sampleEvidence))
    }

    func testCitation_notTrivialFragment() {
        XCTAssertFalse(MediaCompanion.isTrivialFragment("User prefers Bazel for builds."))
    }

    func testCitation_groundingCheck() {
        Phase2TestSupport.assertCitationGrounding(GroundingCheck.citationIntegritySupported)
    }
}
