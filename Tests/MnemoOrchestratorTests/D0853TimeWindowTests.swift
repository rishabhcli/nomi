import XCTest
@testable import MnemoOrchestrator

/// D-0853: profile preamble staleness for TimeWindow (seed 43e1b8a85942).
final class D0853TimeWindowTests: XCTestCase {
    private let seed = "43e1b8a85942"
    func testProfilePreambleStaleness_rng() {
        let profile = Profile(statics: ["lives in SF"], dynamics: [], memories: [])
        XCTAssertFalse(ContextAssembler.staleFacts(in: profile, activeTexts: Set(["lives in SF"])).isEmpty == false)
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: ["works remotely"]))
    }

}
