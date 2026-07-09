import XCTest
@testable import MnemoOrchestrator

/// Shared helpers for D-0501..D-0750 Phase 2 tests.
enum Phase2TestSupport {
    static let sampleEvidence: [Retrieved] = [
        Retrieved(memory: "User prefers Bazel for builds.", similarity: 0.9,
                  source: .init(docId: "d1", path: "/notes/build.md", title: "Build"))
    ]

    static func applyEvents(_ events: [QueryEvent]) -> NotchState {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in events where e != .done { state = NotchReducer.apply(e, to: state) }
        return state
    }

    static func isRenderable(_ events: [QueryEvent]) -> Bool {
        let state = applyEvents(events)
        if let t = state.terminal { return !NotchReducer.message(for: t).isEmpty }
        return !state.answer.isEmpty || !state.reasoning.isEmpty
    }

    static func allTerminalStates() -> [TerminalState] {
        [.empty(nearest: []), .unsupportedAnswer, .engineUnreachable,
         .modelNotLoaded(model: "gpt-oss:20b"), .indexing(path: "/tmp/x.md"),
         .emptyCorpus]
    }

    static func sampleMemory() -> MemoryEntry {
        MemoryEntry(id: "m1", memory: "constituent fact alpha.", version: 1,
                    isLatest: true, isForgotten: false, isStatic: false,
                    parentMemoryId: nil, rootMemoryId: "m1",
                    forgetAfter: nil, forgetReason: nil, history: [])
    }

    /// Property: lifecycle branch events are deterministic for a module.
    static func assertLifecycleDeterministic<T>(
        _ branch: T,
        events: (T) -> [QueryEvent],
        file: StaticString = #file, line: UInt = #line
    ) {
        XCTAssertEqual(events(branch), events(branch), file: file, line: line)
        XCTAssertFalse(events(branch).isEmpty, file: file, line: line)
    }

    /// Citation integrity: grounded claim passes, hallucination fails.
    static func assertCitationGrounding(
        _ supported: (String, [Retrieved]) -> Bool,
        file: StaticString = #file, line: UInt = #line
    ) {
        XCTAssertTrue(supported("User prefers Bazel for builds.", sampleEvidence), file: file, line: line)
        XCTAssertFalse(supported("User prefers CMake for builds.", sampleEvidence), file: file, line: line)
    }
}
