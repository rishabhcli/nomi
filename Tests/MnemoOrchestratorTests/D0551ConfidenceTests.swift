import XCTest
@testable import MnemoOrchestrator

/// D-0551: agentic grep deadlock prevention for Confidence (seed affcea4cbf19).
final class D0551ConfidenceTests: XCTestCase {
    private let seed = "affcea4cbf19"

    func testGrep_deadlockSafe() {
        XCTAssertTrue(Confidence.grepDeadlockSafe())
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
