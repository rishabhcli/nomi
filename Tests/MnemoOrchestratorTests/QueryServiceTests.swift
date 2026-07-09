import XCTest
@testable import MnemoOrchestrator

actor RequestRecorder {
    var requests: [SearchRequest] = []
    func record(_ r: SearchRequest) { requests.append(r) }
}

struct FakeRetriever: Retrieving {
    let hitsByMode: [String: [Retrieved]]
    var recorder: RequestRecorder? = nil
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        await recorder?.record(req)
        return hitsByMode[req.searchMode] ?? []
    }
}

struct FakeGenerator: Generating {
    let tokens: [String]
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            for t in tokens { c.yield(t) }
            c.finish()
        }
    }
}

struct FakeDocsStore: DocumentFetching {
    let records: [String: DocumentRecord]
    func document(_ docId: String) async throws -> DocumentRecord? { records[docId] }
}

private let hit = Retrieved(memory: "I moved to SF.", similarity: 0.8,
    source: .init(docId: "d1", path: "/m/f.md", title: "f", charStart: 0, charEnd: 5))

private func makeService(hitsByMode: [String: [Retrieved]],
                         tokens: [String] = ["ok"],
                         recorder: RequestRecorder? = nil,
                         docs: [String: DocumentRecord] = [:],
                         mountRoot: String = "") -> QueryService {
    QueryService(retriever: FakeRetriever(hitsByMode: hitsByMode, recorder: recorder),
                 generator: FakeGenerator(tokens: tokens),
                 spans: SpanResolver(docs: FakeDocsStore(records: docs)),
                 defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                          threshold: 0.35, limit: 12, container: "mnemo"),
                 mountRoot: mountRoot)
}

final class QueryServiceTests: XCTestCase {
    func testEmitsSourcesBeforeTokensThenDone() async throws {
        let svc = makeService(hitsByMode: ["memories": [hit]], tokens: ["A", "B"])
        var events: [QueryEvent] = []
        for try await e in svc.ask("where do I live?") { events.append(e) }
        if case .routed = events.first { } else { XCTFail("first event must be .routed, got \(String(describing: events.first))") }
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }!
        let tIdx = events.firstIndex(of: .token("A"))!
        XCTAssertLessThan(sIdx, tIdx)
        XCTAssertEqual(events.last, .done)
    }

    func testNotInCorpusDoesNotInvent() async throws {
        let svc = makeService(hitsByMode: [:], tokens: ["SHOULD_NOT_APPEAR"])
        var text = ""
        for try await e in svc.ask("unknown") { if case let .token(t) = e { text += t } }
        XCTAssertFalse(text.contains("SHOULD_NOT_APPEAR"))
        XCTAssertTrue(text.lowercased().contains("don't") || text.lowercased().contains("not"))
    }

    func testDedupesSourceCardsByDocId() async throws {
        let hit2 = Retrieved(memory: "Another fact.", similarity: 0.7,
            source: .init(docId: "d1", path: "/m/f.md", title: "f", charStart: 10, charEnd: 20))
        let svc = makeService(hitsByMode: ["memories": [hit, hit2]])
        var cards: [SourceCard] = []
        for try await e in svc.ask("q") { if case let .sources(c) = e { cards = c } }
        XCTAssertEqual(cards.count, 1)
    }

    func testFallsBackToHybridWhenMemoriesEmpty() async throws {
        let recorder = RequestRecorder()
        let svc = makeService(hitsByMode: ["memories": [], "hybrid": [hit]], recorder: recorder)
        var cards: [SourceCard] = []
        for try await e in svc.ask("q") { if case let .sources(c) = e { cards = c } }
        XCTAssertEqual(cards.count, 1)
        let modes = await recorder.requests.map(\.searchMode)
        XCTAssertEqual(modes, ["memories", "hybrid"])
    }

    func testUsesConfiguredDefaultsOnFirstSearch() async throws {
        let recorder = RequestRecorder()
        let svc = makeService(hitsByMode: ["memories": [hit]], recorder: recorder)
        for try await _ in svc.ask("q") {}
        let first = await recorder.requests[0]
        XCTAssertEqual(first.container, "mnemo")
        XCTAssertEqual(first.limit, 12)
        XCTAssertTrue(first.rerank)
    }

    func testResolvesSpansIntoGenerationContext() async throws {
        // Span comes back nil from retrieval; the service resolves it against doc content.
        let unresolved = Retrieved(memory: "beta gamma", similarity: 0.9,
                                   source: .init(docId: "d9", path: "/d.md", title: "d"))
        let recorder = RequestRecorder()
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [unresolved]], recorder: recorder),
            generator: PromptCapturingGenerator(),
            spans: SpanResolver(docs: FakeDocsStore(records: ["d9": DocumentRecord(content: "alpha beta gamma delta", filepath: nil)])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: nil),
            mountRoot: "")
        var answer = ""
        for try await e in svc.ask("q") { if case let .token(t) = e { answer += t } }
        XCTAssertTrue(answer.contains("@6-16"), "prompt context should carry the resolved span, got: \(answer)")
    }

    func testEvidenceStepsNeverEmbedDocumentText() async throws {
        let secret = "SECRET_DOC_CONTENT_xyz"
        let secretHit = Retrieved(memory: secret, similarity: 0.9,
            source: .init(docId: "d2", path: "/m/s.md", title: "s", charStart: 0, charEnd: 5))
        let svc = makeService(hitsByMode: ["memories": [secretHit]], tokens: ["ok"])
        var steps: [String] = []
        for try await e in svc.ask("what is secret?") {
            if case let .reasoning(s) = e { steps = s }
        }
        for step in steps {
            XCTAssertFalse(step.contains(secret), "reasoning steps must not embed document text")
        }
    }

    func testChitChatSkipsRetrievalAndGeneration() async throws {
        let recorder = RequestRecorder()
        let svc = makeService(hitsByMode: ["memories": [hit]], tokens: ["GENERATED"],
                              recorder: recorder)
        var events: [QueryEvent] = []
        for try await e in svc.ask("hi") { events.append(e) }
        XCTAssertEqual(await recorder.requests.count, 0, "chit-chat must not search")
        XCTAssertFalse(events.contains { if case .sources = $0 { true } else { false } })
        let text = events.compactMap { if case let .token(t) = $0 { t } else { nil } }.joined()
        XCTAssertFalse(text.contains("GENERATED"))
        XCTAssertEqual(events.last, .done)
    }

    func testSourceCardsCarryAbsoluteMountPaths() async throws {
        let bare = Retrieved(memory: "alpha", similarity: 0.9,
                             source: .init(docId: "d1", path: "", title: "t"))
        let svc = makeService(
            hitsByMode: ["memories": [bare]],
            docs: ["d1": DocumentRecord(content: "alpha", filepath: "/fixture.md")],
            mountRoot: "/Users/me/Mnemo/memory")
        var cards: [SourceCard] = []
        for try await e in svc.ask("q") { if case let .sources(c) = e { cards = c } }
        XCTAssertEqual(cards[0].path, "/Users/me/Mnemo/memory/fixture.md")
    }
}

/// Echoes the prompt back as the "answer" so tests can assert on assembled context.
struct PromptCapturingGenerator: Generating {
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            c.yield(prompt)
            c.finish()
        }
    }
}

final class MnemoctlRegistrationTests: XCTestCase {
    private func assertSubcommand(_ name: String, module: String, file: StaticString = #filePath, line: UInt = #line) {
        let path = "Sources/mnemoctl/main.swift"
        XCTAssertTrue(FileManager.default.fileExists(atPath: path), file: file, line: line)
        let main = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"\(name)\":"), "mnemoctl must wire \(name) for \(module)", file: file, line: line)
    }

    func testMnemoctlCoverageSubcommand() { assertSubcommand("coverage", module: "Coverage") }
    func testMnemoctlHighlightSubcommand() { assertSubcommand("highlight", module: "Highlight") }
    func testMnemoctlActionsSubcommand() { assertSubcommand("actions", module: "ActionExtractor") }
    func testMnemoctlSuggestSubcommand() { assertSubcommand("suggest", module: "CorpusSuggester") }
    func testMnemoctlQuerySubcommand() { assertSubcommand("ask", module: "QueryService") }
    func testMnemoctlRouteSubcommand() { assertSubcommand("route", module: "Router") }
    func testMnemoctlEscalateSubcommand() { assertSubcommand("escalate", module: "RouterEscalator") }
    func testMnemoctlEvidenceSubcommand() { assertSubcommand("evidence", module: "EvidenceGathering") }
    func testMnemoctlEnginePingSubcommand() { assertSubcommand("engine-ping", module: "EngineClient") }
    func testMnemoctlEngineWireSubcommand() { assertSubcommand("engine-wire", module: "EngineIntegration") }
    func testMnemoctlVerifyTextSubcommand() { assertSubcommand("verify-text", module: "CitationVerifier") }
    func testMnemoctlSpanSubcommand() { assertSubcommand("span", module: "SpanResolver") }
    func testMnemoctlCharSpanSubcommand() { assertSubcommand("char-span", module: "CharSpan") }
    func testMnemoctlHopPlanSubcommand() { assertSubcommand("hop-plan", module: "LLMHopPlanner") }
    func testMnemoctlAssembleSubcommand() { assertSubcommand("assemble", module: "ContextAssembler") }
    func testMnemoctlPromptSubcommand() { assertSubcommand("prompt", module: "Prompt") }
    func testMnemoctlOllamaPingSubcommand() { assertSubcommand("ollama-ping", module: "OllamaClient") }
    func testMnemoctlIngestMapSubcommand() { assertSubcommand("ingest-map", module: "Ingestion") }
    func testMnemoctlIngestGateSubcommand() { assertSubcommand("ingest-gate", module: "IngestGate") }
    func testMnemoctlConflictsSubcommand() { assertSubcommand("conflicts", module: "ConflictDetector") }
    func testMnemoctlSynthesizeSubcommand() { assertSubcommand("synthesize", module: "LLMSynthesizer") }
    func testMnemoctlSchedulerSubcommand() { assertSubcommand("scheduler", module: "WorkScheduler") }
    func testMnemoctlNotchStateSubcommand() { assertSubcommand("notch-state", module: "NotchReducer") }
    func testMnemoctlDecomposeSubcommand() { assertSubcommand("decompose", module: "QueryDecomposer") }
    func testMnemoctlRewriteSubcommand() { assertSubcommand("rewrite", module: "QueryRewriter") }
    func testMnemoctlScopeClassifySubcommand() { assertSubcommand("scope-classify", module: "ScopeClassifier") }
    func testMnemoctlEffortSubcommand() { assertSubcommand("effort", module: "AdaptiveEffort") }
    func testMnemoctlCacheSubcommand() { assertSubcommand("cache", module: "AnswerCache") }
    func testMnemoctlRankSubcommand() { assertSubcommand("rank", module: "PersonalRanker") }
    func testMnemoctlNumericSubcommand() { assertSubcommand("numeric", module: "NumericReasoner") }
    func testMnemoctlGrepSubcommand() { assertSubcommand("agentic", module: "AgenticGrep") }
    func testMnemoctlBackstopSubcommand() { assertSubcommand("backstop", module: "KeywordBackstop") }
    func testMnemoctlSyncSubcommand() { assertSubcommand("sync", module: "SyncEngine") }
    func testMnemoctlHashSubcommand() { assertSubcommand("hash", module: "ContentHash") }
    func testMnemoctlMemorySubcommand() { assertSubcommand("memory", module: "MemoryDynamics") }
    func testMnemoctlInspectorSubcommand() { assertSubcommand("inspect", module: "Inspector") }
    func testMnemoctlProfileSubcommand() { assertSubcommand("profile", module: "Profile") }
    func testMnemoctlEgressSubcommand() { assertSubcommand("egress-check", module: "EgressGuard") }
}

final class A204RegressionTests: XCTestCase {
    func testA204_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m204", memory: "Forgotten fact 204.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m204",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m204b", memory: "Active fact 204.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m204b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = QueryService.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m204b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA204_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e204", memory: "TTL fact 204.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e204",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(QueryService.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A233RegressionTests: XCTestCase {
    func testA233_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m233", memory: "Forgotten fact 233.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m233",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m233b", memory: "Active fact 233.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m233b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = ProfileDedupe.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m233b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA233_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e233", memory: "TTL fact 233.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e233",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(ProfileDedupe.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A117RegressionTests: XCTestCase {
    func testA117_lifecycleEventsRenderable() {
        let events = QueryService.lifecycleEvents(branch: .retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q117", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        let ok = !state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching
        XCTAssertTrue(ok, "NotchReducer must render .retry")
    }
}

final class A175RegressionTests: XCTestCase {
    func testA175_indexingTerminal() {
        let t = QueryService.indexingTerminalState(path: "/f175.pdf")
        guard case .indexing(let p) = t else { return XCTFail() }
        XCTAssertEqual(p, "/f175.pdf")
    }
    func testA175_selfHealSafe() {
        XCTAssertEqual(QueryService.ingestionSelfHealSafe(orphanIds: ["m175", ""]), ["m175"])
    }
}

final class A262RegressionTests: XCTestCase {
    func testA262_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s262", memory: "Synthesis 262.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s262",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(QueryService.dreamingSafeSynthesis("Synthesis 262.", existing: existing,
                                                      constituents: ["fact 262"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(QueryService.dreamingSafeSynthesis("New synthesis 262.", existing: existing,
                                                     constituents: ["fact 262"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A88RegressionTests: XCTestCase {
    func testA88_lifecycleEventsRenderable() {
        let events = NumericReasoner.lifecycleEvents(branch: .retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q88", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-030: QueryDecomposer splits compound questions for M4 retrieval.
final class QueryDecomposerDocTests: XCTestCase {
    func testDecomposesAndQuestion() {
        let parts = QueryDecomposer.split("what is Bazel and when was it adopted?")
        XCTAssertGreaterThanOrEqual(parts.count, 2)
    }
}
