import XCTest
@testable import MnemoOrchestrator

/// D-0553: profile preamble staleness for CommandParser (seed 8e530e09e34b).
final class D0553CommandParserTests: XCTestCase {
    private let seed = "8e530e09e34b"

    func testProfile_staleFilter() {
        let profile = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(CommandParser.filtersStaleProfilePreamble(profile, active: false))
        XCTAssertTrue(CommandParser.filtersStaleProfilePreamble(profile, active: true))
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

    func testParse_slashCommands() {
        XCTAssertEqual(CommandParser.parse("/help"), .command(.help))
        XCTAssertEqual(CommandParser.parse("plain query"), .query("plain query"))
    }
}
