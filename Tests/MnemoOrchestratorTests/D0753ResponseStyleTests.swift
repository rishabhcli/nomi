import XCTest
@testable import MnemoOrchestrator

/// D-0753: profile preamble staleness for ResponseStyle (seed e9cb115b6c2d).
final class D0753ResponseStyleTests: XCTestCase {
    private let seed = "e9cb115b6c2d"
    func testProfilePreambleStaleness_rng() {
        let profile = Profile(statics: ["lives in SF"], dynamics: [], memories: [])
        XCTAssertFalse(ContextAssembler.staleFacts(in: profile, activeTexts: Set(["lives in SF"])).isEmpty == false)
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: ["works remotely"]))
    }

}
