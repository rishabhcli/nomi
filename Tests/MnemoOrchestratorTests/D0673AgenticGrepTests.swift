import XCTest
@testable import MnemoOrchestrator

/// D-0673: profile preamble staleness for AgenticGrep (seed f143e481fd64).
final class D0673AgenticGrepTests: XCTestCase {
    private let seed = "f143e481fd64"

    func testProfile_staleFilter() {
        let profile = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(AgenticGrep.filtersStaleProfilePreamble(profile, active: false))
        XCTAssertTrue(AgenticGrep.filtersStaleProfilePreamble(profile, active: true))
    }

    func testProfile_phase2StaleDetection() {
        let profile = Profile(statics: ["stale fact"], dynamics: [], memories: [])
        XCTAssertTrue(Phase2Techniques.profilePreambleStale(profile: profile, activeTexts: []))
    }

    func testProfile_summaryExcludesForgotten() {
        let forgotten = MemoryEntry(id: "f", memory: "old", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: true,
                                    parentMemoryId: nil, rootMemoryId: "f",
                                    forgetAfter: nil, forgetReason: "x", history: [])
        let summary = Preferences.summary(memories: [forgotten], strength: [:])
        XCTAssertFalse(summary.contains("old"))
    }
}
