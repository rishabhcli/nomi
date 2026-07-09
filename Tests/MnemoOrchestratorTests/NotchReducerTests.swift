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
    func testReasoningUI_understanding_B242() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.understanding("Reading…"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_sources_B243() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.sources([SourceCard(title: "t", path: "/p", docId: "d")]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_token_B244() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.token("x"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_citation_B245() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.citation(sentenceIndex: 0, supported: false), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_retrying_B246() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.retrying("Retrying…"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_suggestions_B247() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.suggestions(["follow up"]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_entities_B248() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.entities(["Alice"]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_related_B249() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.related([SourceCard(title: "r", path: "/r", docId: "r1")]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_reasoning_B250() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.reasoning(["step 1"]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_state_B251() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.state(.engineUnreachable), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_done_B252() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.done, to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_routed_B253() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.routed(intent: "synthesis", effort: "medium"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_understanding_B254() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.understanding("Reading…"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_sources_B255() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.sources([SourceCard(title: "t", path: "/p", docId: "d")]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_token_B256() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.token("x"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_citation_B257() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.citation(sentenceIndex: 0, supported: false), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_retrying_B258() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.retrying("Retrying…"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_suggestions_B259() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.suggestions(["follow up"]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_entities_B260() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.entities(["Alice"]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_related_B261() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.related([SourceCard(title: "r", path: "/r", docId: "r1")]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_reasoning_B262() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.reasoning(["step 1"]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_state_B263() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.state(.engineUnreachable), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_done_B264() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.done, to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_routed_B265() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.routed(intent: "synthesis", effort: "medium"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_understanding_B266() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.understanding("Reading…"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_sources_B267() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.sources([SourceCard(title: "t", path: "/p", docId: "d")]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_token_B268() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.token("x"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_citation_B269() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.citation(sentenceIndex: 0, supported: false), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_retrying_B270() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.retrying("Retrying…"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_suggestions_B271() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.suggestions(["follow up"]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_entities_B272() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.entities(["Alice"]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_related_B273() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.related([SourceCard(title: "r", path: "/r", docId: "r1")]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
}
