import XCTest
@testable import MnemoOrchestrator

/// D-0993: profile preamble staleness for Inspector (seed 95737f329a64).
final class D0993InspectorTests: XCTestCase {
    private let seed = "95737f329a64"
    func testProfilePreambleStaleness_rng() {
        let profile = Profile(statics: ["lives in SF"], dynamics: [], memories: [])
        XCTAssertFalse(ContextAssembler.staleFacts(in: profile, activeTexts: Set(["lives in SF"])).isEmpty == false)
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: ["works remotely"]))
    }

}
