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
