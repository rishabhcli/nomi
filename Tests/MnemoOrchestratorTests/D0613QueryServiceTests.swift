import XCTest
@testable import MnemoOrchestrator

/// D-0613: profile preamble staleness for QueryService (seed 398c31e9669b).
final class D0613QueryServiceTests: XCTestCase {
    private let seed = "398c31e9669b"

    func testProfile_staleFilter() {
        let profile = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(QueryService.filtersStaleProfilePreamble(profile, active: false))
        XCTAssertTrue(QueryService.filtersStaleProfilePreamble(profile, active: true))
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
