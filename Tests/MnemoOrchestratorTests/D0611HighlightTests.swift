import XCTest
@testable import MnemoOrchestrator

/// D-0611: agentic grep deadlock prevention for Highlight (seed 46c63752166e).
final class D0611HighlightTests: XCTestCase {
    private let seed = "46c63752166e"

    func testGrep_deadlockSafe() {
        XCTAssertTrue(Highlight.grepDeadlockSafe())
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
