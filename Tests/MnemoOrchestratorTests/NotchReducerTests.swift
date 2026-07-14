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
    func testReasoningUI_reasoning_B274() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.reasoning(["step 1"]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_state_B275() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.state(.engineUnreachable), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_done_B276() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.done, to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_routed_B277() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.routed(intent: "synthesis", effort: "medium"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_understanding_B278() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.understanding("Reading…"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_sources_B279() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.sources([SourceCard(title: "t", path: "/p", docId: "d")]), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
    func testReasoningUI_token_B280() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.token("x"), to: s)
        XCTAssertNotEqual(s.phase, .idle)
    }
}

final class A203RegressionTests: XCTestCase {
    func testA203_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m203", memory: "Forgotten fact 203.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m203",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m203b", memory: "Active fact 203.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m203b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = Digest.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m203b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA203_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e203", memory: "TTL fact 203.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e203",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(Digest.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A232RegressionTests: XCTestCase {
    func testA232_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m232", memory: "Forgotten fact 232.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m232",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m232b", memory: "Active fact 232.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m232b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = MemoryInspector.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m232b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA232_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e232", memory: "TTL fact 232.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e232",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(MemoryInspector.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A116RegressionTests: XCTestCase {
    func testA116_lifecycleEventsRenderable() {
        let events = LLMHopPlanner.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q116", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        let ok = !state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching
        XCTAssertTrue(ok, "NotchReducer must render .emptyEvidence")
    }
}

final class A145RegressionTests: XCTestCase {
    func testA145_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d145", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(Confidence.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(Confidence.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA145_unsupportedAnswerEvent() {
        XCTAssertEqual(Confidence.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}

final class A174RegressionTests: XCTestCase {
    func testA174_indexingTerminal() {
        let t = SyncEngine.indexingTerminalState(path: "/f174.pdf")
        guard case .indexing(let p) = t else { return XCTFail() }
        XCTAssertEqual(p, "/f174.pdf")
    }
    func testA174_selfHealSafe() {
        XCTAssertEqual(SyncEngine.ingestionSelfHealSafe(orphanIds: ["m174", ""]), ["m174"])
    }
}

final class A261RegressionTests: XCTestCase {
    func testA261_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s261", memory: "Synthesis 261.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s261",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(QueryService.dreamingSafeSynthesis("Synthesis 261.", existing: existing,
                                                      constituents: ["fact 261"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(QueryService.dreamingSafeSynthesis("New synthesis 261.", existing: existing,
                                                     constituents: ["fact 261"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A87RegressionTests: XCTestCase {
    func testA87_lifecycleEventsRenderable() {
        let events = PersonalRanker.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q87", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// M1a: the reducer captures live observability (per-query timing, per-stage
/// durations, and end-of-query metrics) so the notch can render the trust
/// footer and the reasoning-trace timeline. Data already flows as QueryEvents;
/// these assert the reducer lands it in NotchState.
final class M1aObservabilityReducerTests: XCTestCase {
    func testReducerStoresQueryMetrics() {
        var s = NotchState(phase: .answering, query: "q", answer: "Hi.", sources: [])
        let m = QueryMetrics(firstTokenMs: 120, totalMs: 420, contextTokens: 800,
                             verificationPassRate: 1.0, egressBlockedCount: 0)
        s = NotchReducer.apply(.metrics(m), to: s)
        XCTAssertEqual(s.metrics, m)
    }

    func testReducerAppendsStageTimingsInOrder() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.stage(name: "retrieve", elapsedMs: 90), to: s)
        s = NotchReducer.apply(.stage(name: "generate", elapsedMs: 310), to: s)
        XCTAssertEqual(s.stages, [QueryStage(name: "retrieve", elapsedMs: 90),
                                  QueryStage(name: "generate", elapsedMs: 310)])
    }

    func testRoutedClearsStaleObservability() {
        var s = NotchState(phase: .answering, query: "q", answer: "old", sources: [])
        s = NotchReducer.apply(.stage(name: "retrieve", elapsedMs: 90), to: s)
        s = NotchReducer.apply(.metrics(QueryMetrics(totalMs: 400)), to: s)
        // A fresh query begins — stale timing/metrics must not bleed through.
        s = NotchReducer.apply(.routed(intent: "lookup", effort: "low"), to: s)
        XCTAssertEqual(s.stages, [])
        XCTAssertNil(s.metrics)
    }
}

/// A-029 audit: QueryRewriter has no info-level logging surface.
final class QueryRewriterLoggingAuditTests: XCTestCase {
    func testRewriterFallsBackToOriginalOnGeneratorFailure() async {
        struct FailGen: Generating {
            func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
                AsyncThrowingStream { $0.finish(throwing: OllamaError.notHTTP) }
            }
        }
        let rewritten = await LLMQueryRewriter(generator: FailGen()).rewrite("what about that thing")
        XCTAssertEqual(rewritten, "what about that thing")
    }
}
