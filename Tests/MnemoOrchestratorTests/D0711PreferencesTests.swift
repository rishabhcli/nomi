import XCTest
@testable import MnemoOrchestrator

/// D-0711: agentic grep deadlock prevention for Preferences (seed 55af02fd94e5).
final class D0711PreferencesTests: XCTestCase {
    private let seed = "55af02fd94e5"

    func testGrep_deadlockSafe() {
        XCTAssertTrue(Preferences.grepDeadlockSafe())
    }

    func testGrep_phase2DetectsRepeat() {
        XCTAssertFalse(Phase2Techniques.agenticDeadlockSafe(hopQueries: ["a", "b", "a"]))
        XCTAssertTrue(Phase2Techniques.agenticDeadlockSafe(hopQueries: ["a", "b", "c"]))
    }

    func testGrep_keywordBackstopBounded() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "grep-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "needle".write(to: dir.appending(path: "f.txt"), atomically: true, encoding: .utf8)
        XCTAssertFalse(KeywordBackstop.grep(term: "needle", root: dir.path, maxMatches: 5).isEmpty)
    }
}
