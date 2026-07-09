import XCTest
@testable import MnemoOrchestrator

/// D-0528: citation verifier false-positive elimination for SyncEngine (seed 723f5269cd3d).
final class D0528SyncEngineTests: XCTestCase {
    private let seed = "723f5269cd3d"

    func testCitation_parenthesesPreserved() {
        let claim = "Revenue grew (down from 842) per notes."
        XCTAssertTrue(claim.contains("("))
        XCTAssertTrue(Phase2Techniques.citationNoFalsePositive(
            sentence: claim, evidence: Phase2TestSupport.sampleEvidence))
    }

    func testCitation_notTrivialFragment() {
        XCTAssertFalse(SyncEngine.isTrivialFragment("User prefers Bazel for builds."))
    }

    func testCitation_groundingCheck() {
        Phase2TestSupport.assertCitationGrounding(GroundingCheck.citationIntegritySupported)
    }
}
