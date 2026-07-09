import XCTest
@testable import MnemoOrchestrator

/// #10 — query history recall logic (pure ring, kept in the orchestrator so
/// it's testable independent of the SwiftUI view-model).
final class HistoryRecallTests: XCTestCase {
    func testRecallPreviousWalksBackwards() {
        var h = QueryHistory(cap: 50)
        h.remember("a"); h.remember("b"); h.remember("c")
        XCTAssertEqual(h.previous(), "c")
        XCTAssertEqual(h.previous(), "b")
        XCTAssertEqual(h.previous(), "a")
        XCTAssertEqual(h.previous(), "a", "clamps at the oldest")
    }

    func testRecallNextWalksForwardToEmpty() {
        var h = QueryHistory(cap: 50)
        h.remember("a"); h.remember("b")
        _ = h.previous(); _ = h.previous()   // at "a"
        XCTAssertEqual(h.next(), "b")
        XCTAssertEqual(h.next(), "", "past the newest returns empty (fresh input)")
    }

    func testDeduplicatesConsecutive() {
        var h = QueryHistory(cap: 50)
        h.remember("a"); h.remember("a"); h.remember("b")
        XCTAssertEqual(h.entries, ["a", "b"])
    }

    func testRespectsCap() {
        var h = QueryHistory(cap: 3)
        for q in ["a", "b", "c", "d", "e"] { h.remember(q) }
        XCTAssertEqual(h.entries, ["c", "d", "e"])
    }

    func testEmptyHistoryRecallIsSafe() {
        var h = QueryHistory(cap: 50)
        XCTAssertNil(h.previous())
        XCTAssertNil(h.next())
    }
}
