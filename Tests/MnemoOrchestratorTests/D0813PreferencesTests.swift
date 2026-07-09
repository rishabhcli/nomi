import XCTest
@testable import MnemoOrchestrator

/// D-0813: profile preamble staleness for Preferences (seed dab98acd016d).
final class D0813PreferencesTests: XCTestCase {
    private let seed = "dab98acd016d"
    func testProfilePreambleStaleness_rng() {
        let profile = Profile(statics: ["lives in SF"], dynamics: [], memories: [])
        XCTAssertFalse(ContextAssembler.staleFacts(in: profile, activeTexts: Set(["lives in SF"])).isEmpty == false)
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: ["works remotely"]))
    }

}
