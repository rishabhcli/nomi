import XCTest
@testable import MnemoOrchestrator

/// D-0713: profile preamble staleness for Highlight (seed bdf3b4961b7f).
final class D0713HighlightTests: XCTestCase {
    private let seed = "bdf3b4961b7f"

    func testProfile_staleFilter() {
        let profile = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(Highlight.filtersStaleProfilePreamble(profile, active: false))
        XCTAssertTrue(Highlight.filtersStaleProfilePreamble(profile, active: true))
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
