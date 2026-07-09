import XCTest
@testable import MnemoOrchestrator

/// D-0953: profile preamble staleness for PersonalRanker (seed e2f5e49e3021).
final class D0953PersonalRankerTests: XCTestCase {
    private let seed = "e2f5e49e3021"
    func testProfilePreambleStaleness_rng() {
        let profile = Profile(statics: ["lives in SF"], dynamics: [], memories: [])
        XCTAssertFalse(ContextAssembler.staleFacts(in: profile, activeTexts: Set(["lives in SF"])).isEmpty == false)
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: ["works remotely"]))
    }

}
