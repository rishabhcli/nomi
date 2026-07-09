import XCTest
@testable import MnemoOrchestrator

/// D-0773: profile preamble staleness for SpanResolver (seed 3fd37dea4a16).
final class D0773SpanResolverTests: XCTestCase {
    private let seed = "3fd37dea4a16"
    func testProfilePreambleStaleness_rng() {
        let profile = Profile(statics: ["lives in SF"], dynamics: [], memories: [])
        XCTAssertFalse(ContextAssembler.staleFacts(in: profile, activeTexts: Set(["lives in SF"])).isEmpty == false)
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: ["works remotely"]))
    }

}
