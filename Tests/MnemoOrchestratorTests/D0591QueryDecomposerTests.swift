import XCTest
@testable import MnemoOrchestrator

/// D-0591: agentic grep deadlock prevention for QueryDecomposer (seed 794daab8bb1c).
final class D0591QueryDecomposerTests: XCTestCase {
    private let seed = "794daab8bb1c"

    func testGrep_deadlockSafe() {
        XCTAssertTrue(QueryDecomposer.grepDeadlockSafe())
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
