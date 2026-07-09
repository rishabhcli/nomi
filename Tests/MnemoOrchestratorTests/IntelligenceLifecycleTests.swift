import XCTest
@testable import MnemoOrchestrator

private func ihit(_ id: String, _ text: String, _ sim: Double) -> Retrieved {
    Retrieved(memory: text, similarity: sim, source: .init(docId: id, path: "/\(id).md", title: id))
}

// #1 Agentic multi-hop wired into the answer path.
private struct AgenticFakeSurface: GrepSurface {
    func semantic(_ query: String, scope: String?) async throws -> [GrepHit] {
        [GrepHit(path: "/decision-a.md", lineStart: 1, lineEnd: 2, snippet: "We chose PostgreSQL."),
         GrepHit(path: "/constraint-b.md", lineStart: 3, lineEnd: 4, snippet: "Backups need MySQL.")]
    }
    func literal(_ term: String, scope: String?) async throws -> [GrepHit] { [] }
}
private struct StopPlanner: HopPlanning {
    func nextHop(question: String, evidence: [Retrieved], hops: [HopTrace]) async -> HopDecision {
        .stop(rationale: "done")
    }
}

final class AgenticWiringLifecycleTests: XCTestCase {
    func testMultihopGathersAgenticEvidenceFromMultipleFiles() async throws {
        let agentic = AgenticGrep(surface: AgenticFakeSurface(), planner: StopPlanner(), maxHops: 4)
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [ihit("m1", "a partial fact", 0.55)]]),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "",
            router: FixedRouter(.multihop),
            agentic: agentic)
        var paths = Set<String>()
        for try await e in svc.ask("how does the decision differ from the constraint?") {
            if case let .sources(cards) = e { cards.forEach { paths.insert($0.path) } }
        }
        XCTAssertTrue(paths.contains("/decision-a.md"))
        XCTAssertTrue(paths.contains("/constraint-b.md"))
    }
}

/// Router that always returns a fixed intent (unambiguous).
struct FixedRouter: QueryRouter {
    let intent: Intent
    init(_ i: Intent) { intent = i }
    func classify(_ q: String) -> RoutingResult { RoutingResult(intent: intent, ambiguous: false) }
}

// #3 Self-correcting retry.
private actor DraftBox { var n = 0; func next() -> Int { n += 1; return n } }
private struct TwoTryGenerator: Generating {
    let box: DraftBox
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            Task {
                let attempt = await box.next()
                c.yield(attempt == 1 ? "A wild ungrounded claim." : "Your build tool is Bazel.")
                c.finish()
            }
        }
    }
}
/// Verifier backend: first draft unsupported, corrected draft supported.
private struct RetryBackend: VerificationBackend {
    func similarity(_ a: String, _ b: String) async -> Double { b.contains("Bazel") ? 0.9 : 0.0 }
    func entails(premise: String, hypothesis: String) async -> Bool { hypothesis.contains("Bazel") }
}

final class SelfCorrectionLifecycleTests: XCTestCase {
    func testUngroundedFirstDraftTriggersRetryThatSucceeds() async throws {
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [ihit("d1", "favorite build tool is Bazel", 0.9)]]),
            generator: TwoTryGenerator(box: DraftBox()),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "",
            verifier: CitationVerifier(backend: RetryBackend(), simThreshold: 0.5),
            selfCorrect: true)
        var retried = false
        var finalAnswer = ""
        var unsupportedState = false
        for try await e in svc.ask("what is my build tool?") {
            switch e {
            case .retrying: retried = true
            case .token(let t): finalAnswer += t
            case .state(.unsupportedAnswer): unsupportedState = true
            default: break
            }
        }
        XCTAssertTrue(retried, "an ungrounded first draft must trigger a retry")
        XCTAssertTrue(finalAnswer.contains("Bazel"), "the corrected answer is grounded")
        XCTAssertFalse(unsupportedState, "after a successful correction it is not flagged ungrounded")
    }
}

// #9 Out-of-scope.
final class OutOfScopeLifecycleTests: XCTestCase {
    func testChitChatSkipsRetrievalAndReplies() async throws {
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [ihit("d1", "should not be used", 0.9)]]),
            generator: FakeGenerator(tokens: ["SHOULD_NOT_APPEAR"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "")
        var answer = ""
        var sawSources = false
        for try await e in svc.ask("hello") {
            if case let .token(t) = e { answer += t }
            if case .sources = e { sawSources = true }
        }
        XCTAssertFalse(answer.contains("SHOULD_NOT_APPEAR"), "chit-chat must not run retrieval/generation")
        XCTAssertFalse(sawSources)
        XCTAssertFalse(answer.isEmpty, "a friendly reply is given")
    }
}

// #10 Decomposition retrieves for each sub-question.
final class DecompositionLifecycleTests: XCTestCase {
    func testCompoundQueryRetrievesBothParts() async throws {
        let recorder = RequestRecorder()
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [ihit("d1", "fact", 0.9)]], recorder: recorder),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "")
        for try await _ in svc.ask("what is my build tool and when did I adopt it?") {}
        let queries = await recorder.requests.map(\.q)
        XCTAssertTrue(queries.contains { $0.lowercased().contains("build tool") })
        XCTAssertTrue(queries.contains { $0.lowercased().contains("adopt") })
    }
}
