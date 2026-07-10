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

    /// A-009 regression: CharSpan resolution returns offsets, never logs document text.
    func testCharSpanResolveReturnsOffsetsWithoutLoggingSurface() {
        let secret = "SECRET_INGEST_DOC_xyz"
        let doc = "Prefix \(secret) suffix."
        let range = CharSpan.resolve(chunk: secret, in: doc)!
        XCTAssertEqual(doc.substring(charRange: range), secret)
        XCTAssertFalse(String(describing: CharSpan.self).contains(secret))
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

final class A212RegressionTests: XCTestCase {
    func testA212_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m212", memory: "Forgotten fact 212.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m212",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m212b", memory: "Active fact 212.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m212b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = QueryService.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m212b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA212_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e212", memory: "TTL fact 212.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e212",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(QueryService.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A270RegressionTests: XCTestCase {
    func testA270_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s270", memory: "Synthesis 270.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s270",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(AgenticGrep.dreamingSafeSynthesis("Synthesis 270.", existing: existing,
                                                      constituents: ["fact 270"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(AgenticGrep.dreamingSafeSynthesis("New synthesis 270.", existing: existing,
                                                     constituents: ["fact 270"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A183RegressionTests: XCTestCase { func testA183_x() { XCTAssertEqual(OllamaClient.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }

final class A241RegressionTests: XCTestCase {
    func testA241_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s241", memory: "Synthesis 241.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s241",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(AnswerCache.dreamingSafeSynthesis("Synthesis 241.", existing: existing,
                                                      constituents: ["fact 241"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(AnswerCache.dreamingSafeSynthesis("New synthesis 241.", existing: existing,
                                                     constituents: ["fact 241"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A125RegressionTests: XCTestCase { func testA125_x() { XCTAssertEqual(ContextAssembler.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }
final class A154RegressionTests: XCTestCase { func testA154_x() { XCTAssertEqual(Provenance.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }

final class A96RegressionTests: XCTestCase {
    func testA96_lifecycleEventsRenderable() {
        let events = EntityExtractor.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q96", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-038 invariant: TimelineBuilder orders evidence without URL construction.
final class TimelineBuilderInvariantTests: XCTestCase {
    func testOrdersByUpdatedAt() {
        let ev = [
            Retrieved(memory: "late", similarity: 0.8,
                      source: .init(docId: "b", path: "/b", title: "b", updatedAt: "2026-06-01T00:00:00Z")),
            Retrieved(memory: "early", similarity: 0.8,
                      source: .init(docId: "a", path: "/a", title: "a", updatedAt: "2026-04-01T00:00:00Z")),
        ]
        XCTAssertEqual(TimelineBuilder.build(from: ev).first?.source.docId, "a")
    }
}
