import XCTest
@testable import MnemoOrchestrator

private let bazel = Retrieved(memory: "User's favorite build tool is Bazel.", similarity: 0.82,
    source: .init(docId: "d1", path: "/f.md", title: "Build notes"))

private struct StubProfiles: ProfileFetching {
    let profile: Profile
    func profile(_ q: String, container: String?) async throws -> Profile { profile }
}

/// Records the effort the generator was invoked with.
struct EffortRecordingGenerator: Generating {
    let sink: EffortSink
    let tokens: [String]
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            // The lifecycle encodes effort into the system prompt via Prompt.withEffort.
            Task { await sink.record(system); for t in tokens { c.yield(t) }; c.finish() }
        }
    }
}
actor EffortSink { var systems: [String] = []; func record(_ s: String) { systems.append(s) } }

final class QueryLifecycleTests: XCTestCase {
    private func service(router: QueryRouter = HeuristicRouter(),
                         hits: [String: [Retrieved]] = ["memories": [bazel]],
                         profile: Profile = Profile(statics: ["User is Alex."], dynamics: [], memories: []),
                         generator: Generating = FakeGenerator(tokens: ["ok"])) -> QueryService {
        QueryService(
            retriever: FakeRetriever(hitsByMode: hits),
            generator: generator,
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "",
            router: router,
            profiles: StubProfiles(profile: profile),
            assembler: ContextAssembler(tokenBudget: 4000),
            effort: EffortPolicy(routing: "low", extraction: "low", synthesis: "medium", multihop: "high"))
    }

    func testRouteEventCarriesIntentAndEffort() async throws {
        let svc = service()
        var routeEvent: QueryEvent?
        for try await e in svc.ask("what is my favorite build tool?") {
            if case .routed = e { routeEvent = e; break }
        }
        XCTAssertEqual(routeEvent, .routed(intent: "lookup", effort: "medium"))
    }

    func testProfilePreambleInjectedEveryQuery() async throws {
        let sink = EffortSink()
        let gen = EffortRecordingGenerator(sink: sink, tokens: ["a"])
        let svc = service(profile: Profile(statics: ["User is Alex.", "User loves Rust."], dynamics: [], memories: []),
                          generator: gen)
        for try await _ in svc.ask("what is my favorite build tool?") {}
        let systems = await sink.systems
        XCTAssertTrue(systems.first?.contains("Alex") ?? false, "profile preamble must be in the system prompt")
        XCTAssertTrue(systems.first?.contains("Rust") ?? false)
    }

    func testEffortIsHighForMultihop() async throws {
        let sink = EffortSink()
        let gen = EffortRecordingGenerator(sink: sink, tokens: ["a"])
        let svc = service(generator: gen)
        for try await _ in svc.ask("compare the April note with the June retro and reconcile them") {}
        let systems = await sink.systems
        XCTAssertTrue(systems.first?.contains("high") ?? false, "multihop → high effort")
    }

    func testSourcesEventPrecedesFirstToken() async throws {
        let svc = service(generator: FakeGenerator(tokens: ["A", "B"]))
        var order: [String] = []
        for try await e in svc.ask("what is my favorite build tool?") {
            switch e {
            case .sources: order.append("sources")
            case .token: order.append("token")
            default: break
            }
        }
        let s = order.firstIndex(of: "sources")!
        let t = order.firstIndex(of: "token")!
        XCTAssertLessThan(s, t, "AT-M4.6: sources precede first token")
    }

    /// A-002 audit: Router.swift must not force-unwrap, try!, or swallow errors
    /// on the query path — every input yields a defined RoutingResult.
    func testHeuristicRouterAlwaysReturnsDefinedIntent() {
        let router = HeuristicRouter()
        for q in ["", "?", "compare", "hi", "what is X", "summarize my notes"] {
            let r = router.classify(q)
            XCTAssertFalse(r.intent.rawValue.isEmpty, "undefined intent for '\(q)'")
        }
    }
}

final class A205RegressionTests: XCTestCase {
    func testA205_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m205", memory: "Forgotten fact 205.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m205",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m205b", memory: "Active fact 205.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m205b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = Coverage.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m205b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA205_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e205", memory: "TTL fact 205.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e205",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(Coverage.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A234RegressionTests: XCTestCase {
    func testA234_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m234", memory: "Forgotten fact 234.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m234",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m234b", memory: "Active fact 234.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m234b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = EgressGuard.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m234b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA234_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e234", memory: "TTL fact 234.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e234",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(EgressGuard.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A118RegressionTests: XCTestCase {
    func testA118_lifecycleEventsRenderable() {
        let events = Prompt.lifecycleEvents(branch: .routeAmbiguity)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q118", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        let ok = !state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching
        XCTAssertTrue(ok, "NotchReducer must render .routeAmbiguity")
    }
}

final class A147RegressionTests: XCTestCase {
    func testA147_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d147", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(CommandParser.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(CommandParser.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA147_unsupportedAnswerEvent() {
        XCTAssertEqual(CommandParser.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}

final class A176RegressionTests: XCTestCase {
    func testA176_indexingTerminal() {
        let t = MemoryDynamics.indexingTerminalState(path: "/f176.pdf")
        guard case .indexing(let p) = t else { return XCTFail() }
        XCTAssertEqual(p, "/f176.pdf")
    }
    func testA176_selfHealSafe() {
        XCTAssertEqual(MemoryDynamics.ingestionSelfHealSafe(orphanIds: ["m176", ""]), ["m176"])
    }
}

final class A263RegressionTests: XCTestCase {
    func testA263_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s263", memory: "Synthesis 263.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s263",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(LLMRouterEscalator.dreamingSafeSynthesis("Synthesis 263.", existing: existing,
                                                      constituents: ["fact 263"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(LLMRouterEscalator.dreamingSafeSynthesis("New synthesis 263.", existing: existing,
                                                     constituents: ["fact 263"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A89RegressionTests: XCTestCase {
    func testA89_lifecycleEventsRenderable() {
        let events = TimeWindow.lifecycleEvents(branch: .routeAmbiguity)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q89", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-031: ScopeClassifier distinguishes corpus questions from greetings.
final class ScopeClassifierAuditTests: XCTestCase {
    func testGreetingIsNotCorpusQuestion() {
        XCTAssertFalse(ScopeClassifier.isCorpusQuestion("hi there"))
        XCTAssertTrue(ScopeClassifier.isCorpusQuestion("what is my build tool?"))
    }
}
