import XCTest
@testable import MnemoOrchestrator

/// Serves different results per container so the chat-recall path (searching
/// "<container>-chat") is exercised against fakes.
private struct ContainerRetriever: Retrieving {
    let main: [Retrieved]
    let chat: [Retrieved]
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        req.container == "c-chat" ? chat : main
    }
}

private func hit(_ id: String, _ text: String, _ sim: Double) -> Retrieved {
    Retrieved(memory: text, similarity: sim, source: .init(docId: id, path: "/\(id).md", title: id))
}

final class ChatRecallLifecycleTests: XCTestCase {
    private func service(main: [Retrieved], chat: [Retrieved]) -> QueryService {
        QueryService(
            retriever: ContainerRetriever(main: main, chat: chat),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: false, threshold: 0.35, limit: 12, container: "c"),
            mountRoot: "",
            chatRecallEnabled: true)
    }

    func testRecalledTurnMergesRetitledAndDiscounted() async throws {
        let svc = service(main: [hit("d1", "Aurora slipped.", 0.9)],
                          chat: [hit("t1", "[USER]\nTell me about Aurora dates\n[ASSISTANT]\nIt moved.", 0.8)])
        var sources: [SourceCard] = []
        for try await e in svc.ask("Why did Aurora slip?") {
            if case let .sources(c) = e { sources = c }
        }
        let recalled = sources.first { $0.title == QueryService.chatRecallTitle }
        XCTAssertNotNil(recalled, "chat hit is merged and retitled: \(sources.map(\.title))")
        XCTAssertEqual(recalled!.relevance, 0.8 * 0.7, accuracy: 0.001, "chat evidence is discounted")
    }

    func testEchoOfCurrentQueryIsExcluded() async throws {
        let q = "xyzzy plugh quux frobnicate"
        let svc = service(main: [hit("d1", "unrelated", 0.5)],
                          chat: [hit("t1", "[USER]\n\(q)\n[ASSISTANT]\nno idea", 0.95)])
        var sources: [SourceCard] = []
        for try await e in svc.ask(q) {
            if case let .sources(c) = e { sources = c }
        }
        XCTAssertFalse(sources.contains { $0.title == QueryService.chatRecallTitle },
                       "a transcript echoing this very query is not evidence")
    }

    func testNoRecallWhenDocumentsEmpty() async throws {
        let svc = service(main: [],
                          chat: [hit("t1", "[USER]\nsomething else entirely\n[ASSISTANT]\nanswer", 0.9)])
        var sawChat = false
        for try await e in svc.ask("junk with no document hits") {
            if case let .sources(c) = e, c.contains(where: { $0.title == QueryService.chatRecallTitle }) { sawChat = true }
        }
        XCTAssertFalse(sawChat, "chat recall never becomes the sole evidence")
    }
}
