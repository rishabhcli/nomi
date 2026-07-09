import XCTest
@testable import MnemoOrchestrator

/// D-0793: profile preamble staleness for NotchReducer (seed d194c1bcf0f4).
final class D0793NotchReducerTests: XCTestCase {
    private let seed = "d194c1bcf0f4"
    func testProfilePreambleStaleness_rng() {
        let profile = Profile(statics: ["lives in SF"], dynamics: [], memories: [])
        XCTAssertFalse(ContextAssembler.staleFacts(in: profile, activeTexts: Set(["lives in SF"])).isEmpty == false)
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: ["works remotely"]))
    }

}
