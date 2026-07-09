import XCTest
@testable import MnemoOrchestrator

/// D-0018: SyncEngine TerminalState exhaustiveness (seed e11c4a1ab1ac).
final class D0018SyncEngineTests: XCTestCase {
    private let seed = "e11c4a1ab1ac"

    func testAllTerminalStatesHaveMessages() {
        XCTAssertTrue(SyncEngine.terminalStatesExhaustive())
    }

    func testTerminalLifecycleEventsRenderable() {
        for t in SyncEngine.allTerminalStates() {
            var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
            for e in SyncEngine.terminalLifecycleEvents(t) { state = NotchReducer.apply(e, to: state) }
            XCTAssertNotNil(state.terminal)
            XCTAssertFalse(state.answer.isEmpty, "token event must render message for \(t)")
        }
    }

    func testSelfHealStillWorks() async throws {
        let forgotten = MemoryEntry(id: "m2", memory: "m-m2", version: 1, isLatest: true, isForgotten: false,
                                    isStatic: false, parentMemoryId: nil, rootMemoryId: "m2",
                                    forgetAfter: nil, forgetReason: nil, history: [], documentIds: ["deadDoc"])
        let store = SyncFakeStore([forgotten])
        let docs = SyncFakeDocs([DocumentMeta(id: "live", filepath: "/l.md", title: "l", status: "done",
                                              containerTags: nil, summary: nil, updatedAt: nil)])
        let engine = SyncEngine(store: store, docs: docs, container: "mnemo", forcer: SyncFakeForcer(recorder: ForceRecorder()))
        XCTAssertEqual(try await engine.selfHeal(), 1)
    }

    func testProperty_terminalCountMatchesEnumCases() {
        XCTAssertEqual(SyncEngine.allTerminalStates().count, 6)
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<6 {
            let idx = rng.nextInt(upperBound: 6)
            let t = SyncEngine.allTerminalStates()[idx]
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }
}
