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
}
