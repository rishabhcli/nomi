import XCTest
@testable import MnemoOrchestrator

private func whit(_ id: String, _ text: String, _ sim: Double) -> Retrieved {
    Retrieved(memory: text, similarity: sim, source: .init(docId: id, path: "/\(id).md", title: id))
}

/// Retriever whose memory search is empty but the engine's document search finds it.
private struct DocSearchRetriever: Retrieving, DocumentSearching {
    let docHits: [Retrieved]
    func search(_ req: SearchRequest) async throws -> [Retrieved] { [] }
    func searchDocuments(_ q: String, container: String?, limit: Int) async throws -> [Retrieved] { docHits }
}

final class DocumentSearchSurfaceLifecycleTests: XCTestCase {
    func testFallsBackToDocumentSearchWhenMemoriesEmpty() async throws {
        let svc = QueryService(
            retriever: DocSearchRetriever(docHits: [whit("d1", "The chunk-level answer.", 0.7)]),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "", documentSearchEnabled: true)
        var cards: [SourceCard] = []
        for try await e in svc.ask("something only in chunks") { if case let .sources(c) = e { cards = c } }
        XCTAssertEqual(cards.map(\.docId), ["d1"], "document search rescued an empty memory search")
    }
}

/// Records conversations ingested back into the engine.
actor ConvSink: ConversationIngesting {
    var ingested: [(id: String, turns: Int)] = []
    func ingestConversation(id: String, messages: [(role: String, content: String)], container: String?) async throws {
        ingested.append((id, messages.count))
    }
}

final class ConversationWriteBackLifecycleTests: XCTestCase {
    func testCompletedAnswerIsWrittenBackAsConversation() async throws {
        let sink = ConvSink()
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [whit("d1", "Bazel.", 0.9)]]),
            generator: FakeGenerator(tokens: ["Your build tool is Bazel."]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "", conversationSink: sink)
        for try await _ in svc.ask("what is my build tool?") {}
        // Give the fire-and-forget write-back a moment.
        try await Task.sleep(for: .milliseconds(50))
        let ingested = await sink.ingested
        XCTAssertEqual(ingested.count, 1)
        XCTAssertEqual(ingested[0].turns, 2, "user question + assistant answer")
    }
}
