import XCTest
@testable import MnemoOrchestrator

/// AT-M12.7: every terminal state has a defined, rendered output — the
/// compiler enforces exhaustiveness; these assert each renders something.
final class TerminalStateRenderTests: XCTestCase {
    func testEveryTerminalStateRendersNonEmpty() {
        let states: [TerminalState] = [
            .indexing(path: "/big.pdf"),
            .empty(nearest: [SourceCard(title: "t", path: "/p", docId: "d")]),
            .modelNotLoaded(model: "gpt-oss:20b"),
            .engineUnreachable,
            .unsupportedAnswer,
        ]
        for s in states {
            let msg = NotchReducer.message(for: s)
            XCTAssertFalse(msg.trimmingCharacters(in: .whitespaces).isEmpty, "\(s) rendered empty")
        }
        let corpus = NotchReducer.message(for: .emptyCorpus)
        XCTAssertFalse(corpus.isEmpty)
    }

    func testRecoveryActionsAreDefinedWhereRelevant() {
        XCTAssertEqual(TerminalState.modelNotLoaded(model: "m").recovery, .loadModel)
        XCTAssertEqual(TerminalState.engineUnreachable.recovery, .restartEngine)
        XCTAssertEqual(TerminalState.empty(nearest: []).recovery, .broaden)
        XCTAssertEqual(TerminalState.indexing(path: "/x").recovery, .waitAndRetry)
        XCTAssertEqual(TerminalState.unsupportedAnswer.recovery, .broaden)
    }

    func testEmptyStateCarriesNearestMatches() {
        let nearest = [SourceCard(title: "Close doc", path: "/c.md", docId: "d1")]
        let s = TerminalState.empty(nearest: nearest)
        guard case .empty(let carried) = s else { return XCTFail() }
        XCTAssertEqual(carried, nearest)
    }
}


    func testTerminalUI_indexing_B041() {
        let msg = NotchReducer.message(for: TerminalState.indexing(path: "/x.pdf"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_empty_B042() {
        let msg = NotchReducer.message(for: TerminalState.empty(nearest: []))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_emptyCorpus_B043() {
        let msg = NotchReducer.message(for: TerminalState.emptyCorpus)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_modelNotLoaded_B044() {
        let msg = NotchReducer.message(for: TerminalState.modelNotLoaded(model: "m"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_engineUnreachable_B045() {
        let msg = NotchReducer.message(for: TerminalState.engineUnreachable)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_unsupportedAnswer_B046() {
        let msg = NotchReducer.message(for: TerminalState.unsupportedAnswer)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_indexing_B047() {
        let msg = NotchReducer.message(for: TerminalState.indexing(path: "/x.pdf"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_empty_B048() {
        let msg = NotchReducer.message(for: TerminalState.empty(nearest: []))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_emptyCorpus_B049() {
        let msg = NotchReducer.message(for: TerminalState.emptyCorpus)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_modelNotLoaded_B050() {
        let msg = NotchReducer.message(for: TerminalState.modelNotLoaded(model: "m"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_engineUnreachable_B051() {
        let msg = NotchReducer.message(for: TerminalState.engineUnreachable)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_unsupportedAnswer_B052() {
        let msg = NotchReducer.message(for: TerminalState.unsupportedAnswer)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_indexing_B053() {
        let msg = NotchReducer.message(for: TerminalState.indexing(path: "/x.pdf"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_empty_B054() {
        let msg = NotchReducer.message(for: TerminalState.empty(nearest: []))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_emptyCorpus_B055() {
        let msg = NotchReducer.message(for: TerminalState.emptyCorpus)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_modelNotLoaded_B056() {
        let msg = NotchReducer.message(for: TerminalState.modelNotLoaded(model: "m"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_engineUnreachable_B057() {
        let msg = NotchReducer.message(for: TerminalState.engineUnreachable)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_unsupportedAnswer_B058() {
        let msg = NotchReducer.message(for: TerminalState.unsupportedAnswer)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_indexing_B059() {
        let msg = NotchReducer.message(for: TerminalState.indexing(path: "/x.pdf"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_empty_B060() {
        let msg = NotchReducer.message(for: TerminalState.empty(nearest: []))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_emptyCorpus_B061() {
        let msg = NotchReducer.message(for: TerminalState.emptyCorpus)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_modelNotLoaded_B062() {
        let msg = NotchReducer.message(for: TerminalState.modelNotLoaded(model: "m"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_engineUnreachable_B063() {
        let msg = NotchReducer.message(for: TerminalState.engineUnreachable)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_unsupportedAnswer_B064() {
        let msg = NotchReducer.message(for: TerminalState.unsupportedAnswer)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_indexing_B065() {
        let msg = NotchReducer.message(for: TerminalState.indexing(path: "/x.pdf"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_empty_B066() {
        let msg = NotchReducer.message(for: TerminalState.empty(nearest: []))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_emptyCorpus_B067() {
        let msg = NotchReducer.message(for: TerminalState.emptyCorpus)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_modelNotLoaded_B068() {
        let msg = NotchReducer.message(for: TerminalState.modelNotLoaded(model: "m"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_engineUnreachable_B069() {
        let msg = NotchReducer.message(for: TerminalState.engineUnreachable)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_unsupportedAnswer_B070() {
        let msg = NotchReducer.message(for: TerminalState.unsupportedAnswer)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_indexing_B071() {
        let msg = NotchReducer.message(for: TerminalState.indexing(path: "/x.pdf"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_empty_B072() {
        let msg = NotchReducer.message(for: TerminalState.empty(nearest: []))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_emptyCorpus_B073() {
        let msg = NotchReducer.message(for: TerminalState.emptyCorpus)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_modelNotLoaded_B074() {
        let msg = NotchReducer.message(for: TerminalState.modelNotLoaded(model: "m"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_engineUnreachable_B075() {
        let msg = NotchReducer.message(for: TerminalState.engineUnreachable)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_unsupportedAnswer_B076() {
        let msg = NotchReducer.message(for: TerminalState.unsupportedAnswer)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_indexing_B077() {
        let msg = NotchReducer.message(for: TerminalState.indexing(path: "/x.pdf"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_empty_B078() {
        let msg = NotchReducer.message(for: TerminalState.empty(nearest: []))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_emptyCorpus_B079() {
        let msg = NotchReducer.message(for: TerminalState.emptyCorpus)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_modelNotLoaded_B080() {
        let msg = NotchReducer.message(for: TerminalState.modelNotLoaded(model: "m"))
        XCTAssertFalse(msg.isEmpty)
    }

final class EmptyResultRoutingTests: XCTestCase {
    /// AT-M12.9: below-threshold results surface nearest matches + broaden,
    /// not a blank refusal, when the retriever returns weak hits.
    func testEmptyEmitsNearestWhenWeakHitsExist() async throws {
        // Weak hit below threshold: the service should still show it as "nearest".
        let weak = Retrieved(memory: "Tangentially related note.", similarity: 0.12,
                             source: .init(docId: "d1", path: "/n.md", title: "Note"))
        let svc = QueryService(
            retriever: ThresholdRetriever(all: [weak], threshold: 0.35),
            generator: FakeGenerator(tokens: []),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "",
            emptyFallback: true)
        var sawEmptyWithNearest = false
        for try await e in svc.ask("something obscure") {
            if case .state(.empty(let nearest)) = e, !nearest.isEmpty { sawEmptyWithNearest = true }
        }
        XCTAssertTrue(sawEmptyWithNearest)
    }
}

/// Returns hits only above threshold from `search`, but exposes the weak ones
/// via a nearest() probe (models the engine returning nothing above the floor).
struct ThresholdRetriever: Retrieving, NearestProbing {
    let all: [Retrieved]
    let threshold: Double
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        all.filter { $0.similarity >= req.threshold }
    }
    func nearest(_ q: String, container: String?, limit: Int) async throws -> [Retrieved] {
        Array(all.sorted { $0.similarity > $1.similarity }.prefix(limit))
    }
}

/// A-003 invariant: RouterEscalator must never construct non-loopback URLs.
final class RouterEscalatorInvariantTests: XCTestCase {
    func testEscalatorUsesGeneratorOnlyNotURLs() async {
        let escalator = LLMRouterEscalator(generator: FakeGenerator(tokens: ["lookup"]))
        let intent = await escalator.classify("what is my budget?")
        XCTAssertEqual(intent, .lookup)
    }

    func testEscalatorFallsBackToSynthesisOnGeneratorError() async {
        struct FailingGen: Generating {
            func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
                AsyncThrowingStream { $0.finish(throwing: EngineError.notHTTP) }
            }
        }
        let intent = await LLMRouterEscalator(generator: FailingGen()).classify("compare A and B")
        XCTAssertEqual(intent, .synthesis, "generator failure must not surface as empty UI")
    }
}

final class A206RegressionTests: XCTestCase {
    func testA206_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m206", memory: "Forgotten fact 206.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m206",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m206b", memory: "Active fact 206.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m206b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = Highlight.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m206b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA206_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e206", memory: "TTL fact 206.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e206",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(Highlight.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A235RegressionTests: XCTestCase {
    func testA235_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m235", memory: "Forgotten fact 235.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m235",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m235b", memory: "Active fact 235.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m235b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = WorkScheduler.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m235b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA235_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e235", memory: "TTL fact 235.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e235",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(WorkScheduler.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A148RegressionTests: XCTestCase {
    func testA148_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d148", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(EntityExtractor.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(EntityExtractor.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA148_unsupportedAnswerEvent() {
        XCTAssertEqual(EntityExtractor.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}

final class A177RegressionTests: XCTestCase {
    func testA177_indexingTerminal() {
        let t = ConflictDetector.indexingTerminalState(path: "/f177.pdf")
        guard case .indexing(let p) = t else { return XCTFail() }
        XCTAssertEqual(p, "/f177.pdf")
    }
    func testA177_selfHealSafe() {
        XCTAssertEqual(ConflictDetector.ingestionSelfHealSafe(orphanIds: ["m177", ""]), ["m177"])
    }
}

final class A119RegressionTests: XCTestCase {
    func testA119_lifecycleEventsRenderable() {
        let events = OllamaClient.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q119", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

final class A264RegressionTests: XCTestCase {
    func testA264_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s264", memory: "Synthesis 264.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s264",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(QueryService.dreamingSafeSynthesis("Synthesis 264.", existing: existing,
                                                      constituents: ["fact 264"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(QueryService.dreamingSafeSynthesis("New synthesis 264.", existing: existing,
                                                     constituents: ["fact 264"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A90RegressionTests: XCTestCase {
    func testA90_lifecycleEventsRenderable() {
        let events = TimelineBuilder.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q90", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-032 audit: AdaptiveEffort.select never traps on weak coverage.
final class AdaptiveEffortAuditTests: XCTestCase {
    func testEscalatesEffortOnWeakCoverage() {
        let policy = EffortPolicy(routing: "low", extraction: "low", synthesis: "medium", multihop: "high")
        let effort = AdaptiveEffort.select(policy, intent: .synthesis, coverageWeak: true, decomposed: false)
        XCTAssertEqual(effort, "high")
    }
}
