import XCTest
@testable import MnemoOrchestrator

/// D-0873: profile preamble staleness for EngineIntegration (seed 085067fb5da4).
final class D0873EngineIntegrationTests: XCTestCase {
    private let seed = "085067fb5da4"
    func testProfilePreambleStaleness_rng() {
        let profile = Profile(statics: ["lives in SF"], dynamics: [], memories: [])
        XCTAssertFalse(ContextAssembler.staleFacts(in: profile, activeTexts: Set(["lives in SF"])).isEmpty == false)
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: ["works remotely"]))
    }

}
