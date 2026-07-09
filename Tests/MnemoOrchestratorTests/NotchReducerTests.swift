import XCTest
@testable import MnemoOrchestrator

final class NotchReducerTests: XCTestCase {
    func testReducerBuildsAnswerAndSources() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.sources([SourceCard(title: "t", path: "/p", docId: "d")]), to: s)
        XCTAssertEqual(s.sources.count, 1)
        s = NotchReducer.apply(.token("Hel"), to: s)
        s = NotchReducer.apply(.token("lo"), to: s)
        XCTAssertEqual(s.phase, .answering)
        XCTAssertEqual(s.answer, "Hello")
        s = NotchReducer.apply(.done, to: s)
        XCTAssertEqual(s.phase, .answering)
    }

    func testRouteMovesToSearching() {
        var s = NotchState(phase: .input, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.routed(intent: "synthesis", effort: "medium"), to: s)
        XCTAssertEqual(s.phase, .searching)
    }
}
