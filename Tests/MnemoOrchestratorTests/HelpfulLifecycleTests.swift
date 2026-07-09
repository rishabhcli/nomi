import XCTest
@testable import MnemoOrchestrator

/// Records every SearchRequest so we can assert escalation happened.
private actor SearchRecorder { var reqs: [SearchRequest] = []; func add(_ r: SearchRequest) { reqs.append(r) } }
private struct RecordingRetriever: Retrieving {
    let byMode: [String: [Retrieved]]
    let recorder: SearchRecorder
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        await recorder.add(req)
        return byMode[req.searchMode] ?? []
    }
}

private func hit(_ id: String, _ text: String, _ sim: Double, updatedAt: String? = nil) -> Retrieved {
    Retrieved(memory: text, similarity: sim, source: .init(docId: id, path: "/\(id).md", title: id, updatedAt: updatedAt))
}

final class AutoEscalationLifecycleTests: XCTestCase {
    func testWeakMemoriesEscalatesToBroadenedHybrid() async throws {
        // memories: weak (low sim); hybrid: strong → the service must broaden.
        let recorder = SearchRecorder()
        let retriever = RecordingRetriever(
            byMode: ["memories": [hit("d1", "loosely related", 0.2)],
                     "hybrid": [hit("d2", "The exact answer.", 0.85)]],
            recorder: recorder)
        let svc = QueryService(
            retriever: retriever, generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "")
        var understanding = ""
        var sources: [SourceCard] = []
        for try await e in svc.ask("obscure question") {
            if case let .understanding(u) = e { understanding = u }
            if case let .sources(c) = e { sources = c }
        }
        let modes = await recorder.reqs.map(\.searchMode)
        XCTAssertTrue(modes.contains("hybrid"), "weak coverage must trigger a broadened hybrid search")
        XCTAssertTrue(sources.contains { $0.docId == "d2" }, "the stronger broadened hit is used")
        XCTAssertTrue(understanding.lowercased().contains("broaden"), "user is told it broadened, got: \(understanding)")
    }

    func testStrongCoverageDoesNotEscalate() async throws {
        let recorder = SearchRecorder()
        let retriever = RecordingRetriever(
            byMode: ["memories": [hit("d1", "The strong answer.", 0.85)]], recorder: recorder)
        let svc = QueryService(
            retriever: retriever, generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "")
        for try await _ in svc.ask("clear question") {}
        let modes = await recorder.reqs.map(\.searchMode)
        XCTAssertEqual(modes, ["memories"], "strong coverage answers immediately, no escalation")
    }
}

final class ConversationContextLifecycleTests: XCTestCase {
    func testPriorTurnsAppearInGenerationPrompt() async throws {
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [hit("d1", "fact", 0.9)]]),
            generator: PromptCapturingGenerator(),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "")
        let history = [Turn(question: "What is my build tool?", answer: "Bazel.", sources: [])]
        var answer = ""
        for try await e in svc.ask("why did I pick it?", history: history) {
            if case let .token(t) = e { answer += t }
        }
        XCTAssertTrue(answer.contains("What is my build tool?"), "prior question threaded into the prompt")
        XCTAssertTrue(answer.contains("Bazel."), "prior answer threaded into the prompt")
    }
}

final class RelatedDocsLifecycleTests: XCTestCase {
    func testEmitsSeeAlsoBeyondCitedSources() async throws {
        // Primary returns d1; the nearest-probe surfaces d2/d3 as related.
        let svc = QueryService(
            retriever: RelatedRetriever(primary: [hit("d1", "cited", 0.9)],
                                        nearest: [hit("d1", "cited", 0.9), hit("d2", "related two", 0.4), hit("d3", "related three", 0.3)]),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "", relatedEnabled: true)
        var related: [SourceCard] = []
        for try await e in svc.ask("q") { if case let .related(r) = e { related = r } }
        XCTAssertEqual(Set(related.map(\.docId)), ["d2", "d3"], "see-also excludes the cited doc")
    }
}

private struct RelatedRetriever: Retrieving, NearestProbing {
    let primary: [Retrieved]
    let nearest: [Retrieved]
    func search(_ req: SearchRequest) async throws -> [Retrieved] { primary }
    func nearest(_ q: String, container: String?, limit: Int) async throws -> [Retrieved] { nearest }
}

/// Counts how many times the generator ran, to prove a cache hit skips it.
private actor GenCounter { var n = 0; func bump() { n += 1 } }
private struct CountingGenerator: Generating {
    let counter: GenCounter
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in Task { await counter.bump(); c.yield("Bazel."); c.finish() } }
    }
}

final class AnswerCacheLifecycleTests: XCTestCase {
    func testIdenticalRepeatServedFromCacheWithoutRegenerating() async throws {
        let counter = GenCounter()
        let cache = AnswerCache(ttl: 120)
        func svc() -> QueryService {
            QueryService(
                retriever: FakeRetriever(hitsByMode: ["memories": [hit("d1", "fact", 0.9)]]),
                generator: CountingGenerator(counter: counter),
                spans: SpanResolver(docs: FakeDocsStore(records: [:])),
                defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
                mountRoot: "", cache: cache)
        }
        for try await _ in svc().ask("what is my build tool?") {}
        for try await _ in svc().ask("what is my build tool?") {}   // identical → cache hit
        let runs = await counter.n
        XCTAssertEqual(runs, 1, "second identical query is served from cache, generator not re-run")
    }
}
