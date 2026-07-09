import XCTest
@testable import MnemoOrchestrator

/// D-0833: profile preamble staleness for IngestGate (seed 0952ed1d4453).
final class D0833IngestGateTests: XCTestCase {
    private let seed = "0952ed1d4453"
    func testProfilePreambleStaleness_rng() {
        let profile = Profile(statics: ["lives in SF"], dynamics: [], memories: [])
        XCTAssertFalse(ContextAssembler.staleFacts(in: profile, activeTexts: Set(["lives in SF"])).isEmpty == false)
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: ["works remotely"]))
    }

}
