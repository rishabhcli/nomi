import XCTest
@testable import MnemoOrchestrator

/// D-0653: profile preamble staleness for Confidence (seed a005b4f5e767).
final class D0653ConfidenceTests: XCTestCase {
    private let seed = "a005b4f5e767"

    func testProfile_staleFilter() {
        let profile = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(Confidence.filtersStaleProfilePreamble(profile, active: false))
        XCTAssertTrue(Confidence.filtersStaleProfilePreamble(profile, active: true))
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
