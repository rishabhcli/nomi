import XCTest
@testable import MnemoOrchestrator

/// D-0893: profile preamble staleness for EgressGuard (seed 9fdbc9676435).
final class D0893EgressGuardTests: XCTestCase {
    private let seed = "9fdbc9676435"
    func testProfilePreambleStaleness_rng() {
        let profile = Profile(statics: ["lives in SF"], dynamics: [], memories: [])
        XCTAssertFalse(ContextAssembler.staleFacts(in: profile, activeTexts: Set(["lives in SF"])).isEmpty == false)
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: ["works remotely"]))
    }

}
