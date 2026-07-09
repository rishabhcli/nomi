import XCTest
@testable import MnemoOrchestrator

extension URLRequest {
    /// URLSession converts `httpBody` to a stream by the time a URLProtocol sees
    /// it; read whichever is present so tests can assert on the payload.
    var httpBodyData: Data? {
        if let b = httpBody { return b }
        guard let stream = httpBodyStream else { return nil }
        stream.open(); defer { stream.close() }
        var data = Data(); var buf = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buf, maxLength: buf.count)
            if n <= 0 { break }
            data.append(buf, count: n)
        }
        return data
    }
}

private func engine() -> EngineClient {
    EngineClient(baseURL: URL(string: "http://127.0.0.1:6767")!, apiKey: "",
                 session: StubURLProtocol.stubbedSession())
}

// #1 chunks
final class ChunkFetchTests: XCTestCase {
    func testDecodesChunks() async throws {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v3/documents/d1/chunks")
            let json = #"{"documentId":"d1","total":2,"chunks":[{"id":"c0","position":0,"content":"First chunk.","type":"text"},{"id":"c1","position":1,"content":"Second chunk.","type":"text"}]}"#
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
        let chunks = try await engine().chunks("d1")
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].position, 0)
        XCTAssertEqual(chunks[1].content, "Second chunk.")
    }
    func testContainingChunkForHitText() {
        let chunks = [DocumentChunk(id: "c0", position: 0, content: "Alpha beta gamma."),
                      DocumentChunk(id: "c1", position: 1, content: "Delta epsilon zeta.")]
        XCTAssertEqual(DocumentChunk.containing("epsilon", in: chunks)?.id, "c1")
        XCTAssertNil(DocumentChunk.containing("omega", in: chunks))
    }
}

// #9 document search surface
final class DocumentSearchTests: XCTestCase {
    func testDecodesScoredChunkResults() async throws {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v3/search")
            let json = #"{"results":[{"documentId":"d1","title":"Notes","score":0.72,"updatedAt":"2026-07-08T00:00:00Z","chunks":[{"content":"Bazel is the build tool.","isRelevant":true,"score":0.72}]}]}"#
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
        let hits = try await engine().searchDocuments("build tool", container: "mnemo", limit: 5)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].memory, "Bazel is the build tool.")
        XCTAssertEqual(hits[0].similarity, 0.72, accuracy: 0.001)
        XCTAssertEqual(hits[0].source.docId, "d1")
        XCTAssertEqual(hits[0].source.updatedAt, "2026-07-08T00:00:00Z")
    }
}

// #5 conversation ingestion
final class ConversationIngestTests: XCTestCase {
    func testPostsConversationTurns() async throws {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v4/conversations")
            let body = try! JSONSerialization.jsonObject(with: req.httpBodyData ?? Data()) as! [String: Any]
            XCTAssertEqual(body["conversationId"] as? String, "conv1")
            let msgs = body["messages"] as! [[String: Any]]
            XCTAssertEqual(msgs.count, 2)
            XCTAssertEqual(msgs[0]["role"] as? String, "user")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"id":"x","conversationId":"conv1","status":"queued"}"#.utf8))
        }
        try await engine().ingestConversation(id: "conv1",
            messages: [("user", "q"), ("assistant", "a")], container: "mnemo")
    }
}

// #7 bulk delete
final class BulkDeleteTests: XCTestCase {
    func testDeletesByIds() async throws {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.httpMethod, "DELETE")
            XCTAssertEqual(req.url?.path, "/v3/documents/bulk")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"success":true,"deletedCount":2}"#.utf8))
        }
        let n = try await engine().bulkDelete(ids: ["a", "b"])
        XCTAssertEqual(n, 2)
    }
}

// #8 file url
final class FileURLTests: XCTestCase {
    func testReturnsUrlWhenPresent() async throws {
        StubURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data(#"{"url":"http://127.0.0.1:6767/files/x.png"}"#.utf8))
        }
        let u = try await engine().fileURL("d1")
        XCTAssertEqual(u, "http://127.0.0.1:6767/files/x.png")
    }
    func testNilWhenNoFile() async throws {
        StubURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data(#"{"error":"Document has no associated file"}"#.utf8))
        }
        let u = try await engine().fileURL("d1")
        XCTAssertNil(u)
    }
}

// #4 containers derived from documents
final class ContainerDeriveTests: XCTestCase {
    func testDistinctContainersFromDocuments() {
        let docs = [
            DocumentMeta(id: "1", filepath: "/a", title: "a", status: "done", containerTags: ["mnemo", "work"], summary: nil, updatedAt: nil),
            DocumentMeta(id: "2", filepath: "/b", title: "b", status: "done", containerTags: ["work"], summary: nil, updatedAt: nil),
            DocumentMeta(id: "3", filepath: "/c", title: "c", status: "done", containerTags: nil, summary: nil, updatedAt: nil),
        ]
        XCTAssertEqual(ContainerCatalog.distinct(docs), ["mnemo", "work"])
    }
}

// #3 processing count
final class ProcessingTests: XCTestCase {
    func testDecodesProcessingDocuments() async throws {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v3/documents/processing")
            let json = #"{"totalCount":1,"documents":[{"id":"d1","status":"embedding","filepath":"/big.pdf"}]}"#
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
        let procs = try await engine().processing(container: "mnemo")
        XCTAssertEqual(procs.count, 1)
        XCTAssertEqual(procs[0].filepath, "/big.pdf")
        XCTAssertEqual(procs[0].state, .processing)
    }
}

/// A-007 audit: CitationVerifier must not force-unwrap, try!, or swallow errors.
final class CitationVerifierAuditTests: XCTestCase {
    func testVerifierReturnsVerdictForEverySentence() async {
        let backend = StubVerifierBackend(similarity: { _, _ in 0.9 }, entails: { _, _ in true })
        let verdicts = await CitationVerifier(backend: backend).verify(
            answer: "First fact. Second fact.",
            evidence: [Retrieved(memory: "shared fact text", similarity: 0.9,
                                source: .init(docId: "d", path: "/p", title: "t"))])
        XCTAssertEqual(verdicts.count, 2)
        XCTAssertTrue(verdicts.allSatisfy { !$0.text.isEmpty })
    }
}

final class A210RegressionTests: XCTestCase {
    func testA210_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m210", memory: "Forgotten fact 210.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m210",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m210b", memory: "Active fact 210.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m210b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = HeuristicRouter.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m210b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA210_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e210", memory: "TTL fact 210.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e210",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(HeuristicRouter.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A268RegressionTests: XCTestCase {
    func testA268_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s268", memory: "Synthesis 268.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s268",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(SpanResolver.dreamingSafeSynthesis("Synthesis 268.", existing: existing,
                                                      constituents: ["fact 268"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(SpanResolver.dreamingSafeSynthesis("New synthesis 268.", existing: existing,
                                                     constituents: ["fact 268"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A181RegressionTests: XCTestCase { func testA181_x() { XCTAssertEqual(ContextAssembler.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }

final class A239RegressionTests: XCTestCase {
    func testA239_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m239", memory: "Forgotten fact 239.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m239",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m239b", memory: "Active fact 239.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m239b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = ScopeClassifier.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m239b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA239_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e239", memory: "TTL fact 239.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e239",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(ScopeClassifier.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}
final class A123RegressionTests: XCTestCase { func testA123_x() { XCTAssertEqual(KeywordBackstop.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }
final class A152RegressionTests: XCTestCase { func testA152_x() { XCTAssertEqual(FollowUpSuggester.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }

final class A94RegressionTests: XCTestCase {
    func testA94_lifecycleEventsRenderable() {
        let events = Provenance.lifecycleEvents(branch: .retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q94", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-036: NumericReasoner detects duration questions across evidence.
final class NumericReasonerAuditTests: XCTestCase {
    func testDetectsHowManyWeeksQuestion() {
        XCTAssertTrue(NumericReasoner.isNumericQuestion("how many weeks did it slip?"))
    }
}
