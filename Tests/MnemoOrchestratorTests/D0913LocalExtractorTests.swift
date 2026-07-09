import XCTest
@testable import MnemoOrchestrator

/// D-0913: profile preamble staleness for LocalExtractor (seed 5fa1e66a53bb).
final class D0913LocalExtractorTests: XCTestCase {
    private let seed = "5fa1e66a53bb"
    func testProfilePreambleStaleness_rng() {
        let profile = Profile(statics: ["lives in SF"], dynamics: [], memories: [])
        XCTAssertFalse(ContextAssembler.staleFacts(in: profile, activeTexts: Set(["lives in SF"])).isEmpty == false)
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: ["works remotely"]))
    }

}
