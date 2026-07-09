import XCTest
@testable import MnemoOrchestrator

/// Scriptable fake for the engine's document surface.
actor FakeDocumentSource: DocumentIndexing {
    var docs: [DocumentMeta]
    init(_ docs: [DocumentMeta]) { self.docs = docs }
    func set(_ docs: [DocumentMeta]) { self.docs = docs }
    func documentsList(container: String?) async throws -> [DocumentMeta] { docs }
}

private func doc(_ id: String, path: String, status: String) -> DocumentMeta {
    DocumentMeta(id: id, filepath: path, title: path, status: status,
                 containerTags: ["mnemo"], summary: nil, updatedAt: nil)
}

final class IngestIndexTests: XCTestCase {
    func testEmitsTransitionsOnRefresh() async throws {
        let source = FakeDocumentSource([doc("d1", path: "/a.md", status: "queued")])
        let index = IngestIndex(docs: source, container: "mnemo")
        var events: [IngestEvent] = []
        let stream = await index.events()
        await index.refresh()
        await source.set([doc("d1", path: "/a.md", status: "extracting")])
        await index.refresh()
        await source.set([doc("d1", path: "/a.md", status: "done")])
        await index.refresh()
        await index.finishEvents()
        for await e in stream { events.append(e) }
        XCTAssertEqual(events.map(\.to), [.queued, .processing, .ready])
        XCTAssertEqual(events[1].from, .queued)
        XCTAssertEqual(events[2].docId, "d1")
    }

    func testQueueDepthCountsUnfinishedDocs() async throws {
        let source = FakeDocumentSource([
            doc("d1", path: "/a.md", status: "done"),
            doc("d2", path: "/b.pdf", status: "embedding"),
            doc("d3", path: "/c.png", status: "queued"),
        ])
        let index = IngestIndex(docs: source, container: "mnemo")
        await index.refresh()
        let depth = await index.queueDepth
        XCTAssertEqual(depth, 2)
    }

    func testStateLookupByIdAndPath() async throws {
        let source = FakeDocumentSource([doc("d9", path: "/notes/x.md", status: "chunking")])
        let index = IngestIndex(docs: source, container: "mnemo")
        await index.refresh()
        let byId = await index.state(of: "d9")
        let pending = await index.pendingPaths()
        XCTAssertEqual(byId, .processing)
        XCTAssertEqual(pending, ["/notes/x.md"])
    }

    func testErrorStateSurfacesFailedDocs() async throws {
        let source = FakeDocumentSource([doc("bad", path: "/corrupt.pdf", status: "failed")])
        let index = IngestIndex(docs: source, container: "mnemo")
        await index.refresh()
        let s = await index.state(of: "bad")
        XCTAssertEqual(s, .error)
        let failed = await index.failedPaths()
        XCTAssertEqual(failed, ["/corrupt.pdf"])
    }
}

final class QueryServiceIndexingStateTests: XCTestCase {
    func testEmitsIndexingStateInsteadOfEmptyAnswer() async throws {
        // No hits, but a doc is mid-ingest → the query path must say "indexing",
        // never the not-in-corpus refusal (AT-M2.3).
        let source = FakeDocumentSource([doc("d1", path: "/big.pdf", status: "extracting")])
        let index = IngestIndex(docs: source, container: "mnemo")
        await index.refresh()
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: [:]),
            generator: FakeGenerator(tokens: ["NOPE"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                     threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "",
            ingestIndex: index)
        var events: [QueryEvent] = []
        for try await e in svc.ask("what's in the big report?") { events.append(e) }
        XCTAssertTrue(events.contains(.state(.indexing(path: "/big.pdf"))),
                      "expected indexing state, got: \(events)")
        XCTAssertFalse(events.contains { if case .token = $0 { true } else { false } },
                       "no invented answer while the corpus is still indexing")
    }

    func testEmptyCorpusStillRefusesWhenNothingPending() async throws {
        let source = FakeDocumentSource([doc("d1", path: "/a.md", status: "done")])
        let index = IngestIndex(docs: source, container: "mnemo")
        await index.refresh()
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: [:]),
            generator: FakeGenerator(tokens: []),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                     threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "",
            ingestIndex: index)
        var sawRefusal = false
        for try await e in svc.ask("unknown topic") {
            if case let .token(t) = e, t.lowercased().contains("don't have") { sawRefusal = true }
        }
        XCTAssertTrue(sawRefusal)
    }
}
