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

    // B-001: view-local chrome maps to reducer phases — no orphan state.
    func testSurfacePhaseBindingRetainsAnswerHeightOnlyWhileAnswering() {
        XCTAssertTrue(NotchSurfacePhaseBinding.shouldRetainAnswerHeight(phase: .answering, listening: false))
        XCTAssertTrue(NotchSurfacePhaseBinding.shouldRetainAnswerHeight(phase: .state, listening: false))
        XCTAssertFalse(NotchSurfacePhaseBinding.shouldRetainAnswerHeight(phase: .input, listening: false))
        XCTAssertFalse(NotchSurfacePhaseBinding.shouldRetainAnswerHeight(phase: .searching, listening: false))
        XCTAssertFalse(NotchSurfacePhaseBinding.shouldRetainAnswerHeight(phase: .answering, listening: true))
    }

    func testSurfacePhaseBindingTrayAndFocus() {
        XCTAssertTrue(NotchSurfacePhaseBinding.showsTray(phase: .input, listening: false))
        XCTAssertFalse(NotchSurfacePhaseBinding.showsTray(phase: .idle, listening: false))
        XCTAssertFalse(NotchSurfacePhaseBinding.showsTray(phase: .input, listening: true))
        XCTAssertTrue(NotchSurfacePhaseBinding.shouldFocusInput(phase: .input))
        XCTAssertTrue(NotchSurfacePhaseBinding.shouldFocusInput(phase: .answering))
        XCTAssertFalse(NotchSurfacePhaseBinding.shouldFocusInput(phase: .searching))
    }
    func testReasoningUI_routed_B241() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.routed(intent: "synthesis", effort: "medium"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
}
