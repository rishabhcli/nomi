import XCTest
@testable import MnemoOrchestrator

/// D-0933: profile preamble staleness for OllamaClient (seed 23ae582c2ddc).
final class D0933OllamaClientTests: XCTestCase {
    private let seed = "23ae582c2ddc"
    func testProfilePreambleStaleness_rng() {
        let profile = Profile(statics: ["lives in SF"], dynamics: [], memories: [])
        XCTAssertFalse(ContextAssembler.staleFacts(in: profile, activeTexts: Set(["lives in SF"])).isEmpty == false)
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: ["works remotely"]))
    }

}
