import XCTest
@testable import MnemoOrchestrator

/// AT-M12.7: drive every terminal state through the reducer and assert each
/// produces a rendered, non-empty output (none is a silent empty screen).
final class StateDriverTests: XCTestCase {
    func testAllTerminalStatesReduceToRenderedOutput() {
        let cases: [(QueryEvent, String)] = [
            (.state(.indexing(path: "/a.pdf")), "indexing"),
            (.state(.empty(nearest: [])), "match"),
            (.state(.modelNotLoaded(model: "gpt-oss:20b")), "model"),
            (.state(.engineUnreachable), "engine"),
            (.state(.unsupportedAnswer), "ground"),
        ]
        for (event, expectedFragment) in cases {
            var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
            s = NotchReducer.apply(event, to: s)
            XCTAssertEqual(s.phase, .state)
            guard let terminal = s.terminal else { return XCTFail("no terminal for \(event)") }
            let msg = NotchReducer.message(for: terminal).lowercased()
            XCTAssertTrue(msg.contains(expectedFragment),
                          "\(terminal) message '\(msg)' missing '\(expectedFragment)'")
        }
    }

    func testAnswerStateStillRendersAfterTerminalReset() {
        var s = NotchState(phase: .state, query: "q", answer: "", sources: [], terminal: .engineUnreachable)
        // A fresh answer stream clears back into answering.
        s = NotchReducer.apply(.token("Recovered."), to: s)
        XCTAssertEqual(s.phase, .answering)
        XCTAssertEqual(s.answer, "Recovered.")
    }
}
