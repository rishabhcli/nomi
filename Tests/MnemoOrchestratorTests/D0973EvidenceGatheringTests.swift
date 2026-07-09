import XCTest
@testable import MnemoOrchestrator

/// D-0973: profile preamble staleness for EvidenceGathering (seed fd8596ddf751).
final class D0973EvidenceGatheringTests: XCTestCase {
    private let seed = "fd8596ddf751"
    func testProfilePreambleStaleness_rng() {
        let profile = Profile(statics: ["lives in SF"], dynamics: [], memories: [])
        XCTAssertFalse(ContextAssembler.staleFacts(in: profile, activeTexts: Set(["lives in SF"])).isEmpty == false)
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: ["works remotely"]))
    }

}
