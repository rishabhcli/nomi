import XCTest
@testable import MnemoOrchestrator

/// D-0508: citation verifier false-positive elimination for Coverage (seed 3f4d5ce58033).
final class D0508CoverageTests: XCTestCase {
    private let seed = "3f4d5ce58033"

    func testCitation_parenthesesPreserved() {
        let claim = "Revenue grew (down from 842) per notes."
        XCTAssertTrue(claim.contains("("))
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(
            sentence: claim, evidence: Phase2TestSupport.sampleEvidence))
    }

    func testCitation_notTrivialFragment() {
        XCTAssertFalse(Coverage.isTrivialFragment("User prefers Bazel for builds."))
    }

    func testCitation_groundingCheck() {
        Phase2TestSupport.assertCitationGrounding(GroundingCheck.citationIntegritySupported)
    }
}
