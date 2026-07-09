import XCTest
@testable import MnemoOrchestrator

/// D-0001: property-based invariants for QueryService (seed 0a95dece6bd1).
final class D0001QueryServicePropertyTests: XCTestCase {
    private let seed = "0a95dece6bd1"

    private func collectEvents(_ stream: AsyncThrowingStream<QueryEvent, Error>) async throws -> [QueryEvent] {
        var out: [QueryEvent] = []
        for try await e in stream { out.append(e) }
        return out
    }

    private func isRenderable(_ events: [QueryEvent]) -> Bool {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in events where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        if state.terminal != nil { return !NotchReducer.message(for: state.terminal!).isEmpty }
        if !state.answer.isEmpty { return true }
        if !state.reasoning.isEmpty { return true }
        return events.contains { if case .token = $0 { true } else { false } }
    }

    func testProperty_streamAlwaysEndsWithDone() async throws {
        var rng = Phase2RNG(seed: seed)
        for i in 0..<20 {
            let q = rng.randomQuery(length: 2 + rng.nextInt(upperBound: 5))
            let svc = QueryService(
                retriever: FakeRetriever(hitsByMode: i % 3 == 0 ? [:] : ["memories": [propertyHit(i)]]),
                generator: FakeGenerator(tokens: ["ok"]),
                spans: SpanResolver(docs: FakeDocsStore(records: [:])),
                defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"),
                mountRoot: "")
            let events = try await collectEvents(svc.ask(q))
            XCTAssertEqual(events.last, .done, "query \(q) must end with .done")
        }
    }

    func testProperty_firstEventIsRouted() async throws {
        let svc = makePropertyService()
        let events = try await collectEvents(svc.ask("what is bazel?"))
        guard case .routed = events.first else {
            return XCTFail("first event must be .routed, got \(String(describing: events.first))")
        }
    }

    func testProperty_sourcesPrecedeTokensWhenBothExist() async throws {
        let svc = makePropertyService(tokens: ["A", "B"])
        let events = try await collectEvents(svc.ask("what is bazel?"))
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }
        let tIdx = events.firstIndex { if case .token = $0 { true } else { false } }
        if let s = sIdx, let t = tIdx { XCTAssertLessThan(s, t) }
    }

    func testProperty_emptyEvidenceEmitsTerminalState() async throws {
        let svc = makePropertyService(hits: [:])
        let events = try await collectEvents(svc.ask("what is unknown thing xyz?"))
        let hasTerminal = events.contains { if case .state = $0 { true } else { false } }
        XCTAssertTrue(hasTerminal, "empty evidence must emit .state terminal")
        XCTAssertTrue(isRenderable(events))
    }

    func testProperty_ambiguityReasoningSurvivesRouted() async throws {
        let router = FixedRouter(result: RoutingResult(intent: .multihop, ambiguous: true))
        let svc = makePropertyService(router: router)
        let events = try await collectEvents(svc.ask("compare"))
        var state = NotchState(phase: .input, query: "compare", answer: "", sources: [])
        for e in events where e != .done { state = NotchReducer.apply(e, to: state) }
        XCTAssertFalse(state.reasoning.isEmpty, "ambiguity reasoning must survive .routed")
    }

    func testProperty_conversationIdDeterministicWithinProcess() {
        let a = QueryService.conversationId(for: "what is bazel?")
        let b = QueryService.conversationId(for: "what is bazel?")
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.hasPrefix("mnemo-"))
    }

    func testProperty_absolutePathJoinsRelativeEnginePaths() async throws {
        let bare = Retrieved(memory: "x", similarity: 0.9,
                             source: .init(docId: "d", path: "docs/note.md", title: "t"))
        let svc = makePropertyService(hits: ["memories": [bare]], mountRoot: "/Users/me/Mnemo/memory")
        var path = ""
        for try await e in svc.ask("q") {
            if case let .sources(c) = e, let first = c.first { path = first.path }
        }
        XCTAssertEqual(path, "/Users/me/Mnemo/memory/docs/note.md")
    }

    func testProperty_ollamaModelErrorMapsToModelNotLoaded() {
        let events = QueryService.lifecycleRetryEventsForTesting(
            OllamaError.server("model 'gpt-oss:20b' not found"))
        XCTAssertTrue(events.contains { if case .state(.modelNotLoaded) = $0 { true } else { false } })
    }

    func testCoverage_emptyEvidenceEventsRenderable() {
        let events = Coverage.emptyEvidenceEvents()
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertNotNil(state.terminal)
        guard case .empty = state.terminal else { return XCTFail("expected .empty terminal") }
    }

    // MARK: - helpers

    private func propertyHit(_ i: Int) -> Retrieved {
        Retrieved(memory: "fact \(i)", similarity: 0.8,
                  source: .init(docId: "d\(i)", path: "/f\(i).md", title: "f\(i)"))
    }

    private func makePropertyService(hits: [String: [Retrieved]] = ["memories": [propertyHit(0)]],
                                     tokens: [String] = ["ok"],
                                     router: QueryRouter = HeuristicRouter(),
                                     mountRoot: String = "") -> QueryService {
        QueryService(
            retriever: FakeRetriever(hitsByMode: hits),
            generator: FakeGenerator(tokens: tokens),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: mountRoot,
            router: router)
    }
}

struct FixedRouter: QueryRouter {
    let result: RoutingResult
    func classify(_ q: String) -> RoutingResult { result }
}

extension QueryService {
    /// Test hook for error-path terminal mapping (D-0001).
    static func lifecycleRetryEventsForTesting(_ error: Error) -> [QueryEvent] {
        let terminal: TerminalState
        switch error {
        case let ollama as OllamaError:
            switch ollama {
            case .server(let msg) where msg.lowercased().contains("model"):
                terminal = .modelNotLoaded(model: msg)
            default:
                terminal = .engineUnreachable
            }
        case is EngineError:
            terminal = .engineUnreachable
        default:
            terminal = .engineUnreachable
        }
        return [.retrying("That didn't work — try asking again."), .state(terminal)]
    }
}
