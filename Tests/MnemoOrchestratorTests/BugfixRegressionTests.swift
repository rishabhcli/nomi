import XCTest
@testable import MnemoOrchestrator

/// Regressions for bugs found in the full-app audit (2026-07-09).

final class ReducerResetRegressionTests: XCTestCase {
    /// A follow-up query must not render the previous query's terminal state.
    func testRoutedClearsStaleTerminalAndAnswer() {
        var s = NotchState(phase: .state, query: "q2", answer: "old answer",
                           sources: [SourceCard(title: "t", path: "/p", docId: "d")],
                           terminal: .engineUnreachable, unsupportedSentences: [0, 1])
        s = NotchReducer.apply(.routed(intent: "lookup", effort: "medium"), to: s)
        XCTAssertEqual(s.phase, .searching)
        XCTAssertEqual(s.answer, "")
        XCTAssertTrue(s.sources.isEmpty)
        XCTAssertNil(s.terminal, "stale terminal must be cleared at query start")
        XCTAssertTrue(s.unsupportedSentences.isEmpty)
    }

    /// Tokens supersede a terminal state so the answer renders, not the dead end.
    func testTokenClearsTerminal() {
        var s = NotchState(phase: .state, query: "q", answer: "", sources: [], terminal: .empty(nearest: []))
        s = NotchReducer.apply(.token("Hello"), to: s)
        XCTAssertEqual(s.phase, .answering)
        XCTAssertNil(s.terminal)
        XCTAssertEqual(s.answer, "Hello")
    }

    /// The full lifecycle of a second query over a state left dirty by the first.
    func testSecondQueryAfterTerminalRendersAnswer() {
        var s = NotchState(phase: .idle, query: "", answer: "", sources: [])
        // First query ends empty.
        s = NotchReducer.apply(.routed(intent: "lookup", effort: "medium"), to: s)
        s = NotchReducer.apply(.state(.empty(nearest: [])), to: s)
        XCTAssertNotNil(s.terminal)
        // Second query streams an answer.
        s = NotchReducer.apply(.routed(intent: "synthesis", effort: "medium"), to: s)
        s = NotchReducer.apply(.sources([SourceCard(title: "t", path: "/p", docId: "d")]), to: s)
        s = NotchReducer.apply(.token("Bazel."), to: s)
        s = NotchReducer.apply(.done, to: s)
        XCTAssertEqual(s.phase, .answering)
        XCTAssertNil(s.terminal)
        XCTAssertEqual(s.answer, "Bazel.")
    }
}

final class VerdictParseRegressionTests: XCTestCase {
    func testStandaloneVerdictWins() {
        XCTAssertTrue(LocalVerificationBackend.parseVerdict("YES"))
        XCTAssertFalse(LocalVerificationBackend.parseVerdict("NO"))
    }

    func testNoInsideWordsDoesNotFlipYes() {
        // "NOT"/"KNOWN"/"CANNOT"/"NONE" all contain "NO" but must not count.
        XCTAssertTrue(LocalVerificationBackend.parseVerdict(
            "The claim is NOT contradicted by the KNOWN facts. Answer: YES"))
        XCTAssertTrue(LocalVerificationBackend.parseVerdict(
            "I cannot find a contradiction. NONE apply. YES"))
    }

    func testLastStandaloneVerdictWins() {
        XCTAssertFalse(LocalVerificationBackend.parseVerdict(
            "First I thought YES, but on reflection the answer is NO"))
        XCTAssertTrue(LocalVerificationBackend.parseVerdict(
            "Maybe NO at first glance, but ultimately YES"))
    }

    func testNoVerdictTokenIsUnsupported() {
        XCTAssertFalse(LocalVerificationBackend.parseVerdict("I am not sure about this."))
        XCTAssertFalse(LocalVerificationBackend.parseVerdict(""))
    }
}
