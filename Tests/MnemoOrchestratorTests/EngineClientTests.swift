import XCTest
@testable import MnemoOrchestrator

final class EngineClientTests: XCTestCase {
    /// Wire format captured from the real self-hosted engine (v4/search, memories mode).
    func testDecodesMemoryResults() async throws {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v4/search")
            let body = try XCTUnwrap(req.bodyStreamData())
            let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(sent["searchMode"] as? String, "memories")
            XCTAssertEqual(sent["containerTag"] as? String, "mnemo")
            let include = try XCTUnwrap(sent["include"] as? [String: Any])
            XCTAssertEqual(include["documents"] as? Bool, true)
            let json = """
            {"results":[{"id":"mem_1","memory":"I moved to SF.","similarity":0.82,
              "rootMemoryId":null,"version":1,"filepath":"/notes/life.md",
              "documents":[{"id":"docA","title":"life"}]}],
             "timing":12,"total":1}
            """
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
        let client = makeClient()
        var req = SearchRequest(q: "where do I live?")
        req.container = "mnemo"
        let out = try await client.search(req)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].memory, "I moved to SF.")
        XCTAssertEqual(out[0].source.docId, "docA")
        XCTAssertEqual(out[0].source.title, "life")
        XCTAssertEqual(out[0].source.path, "/notes/life.md")
    }

    /// Chunk-mode results (searchMode: documents/hybrid) carry `chunk` text instead of `memory`.
    func testDecodesChunkResults() async throws {
        StubURLProtocol.handler = { req in
            let json = """
            {"results":[{"id":"chk_1","chunk":"My favorite build tool is Bazel.","similarity":0.79,
              "metadata":{"source":"supermemoryfs"},"filepath":null,"version":1,
              "documents":[{"id":"docB","title":"Build tooling notes"}]}],
             "timing":9,"total":1}
            """
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
        let client = makeClient()
        let out = try await client.search(SearchRequest(q: "build tool", searchMode: "documents", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"))
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].memory, "My favorite build tool is Bazel.")
        XCTAssertEqual(out[0].source.docId, "docB")
        XCTAssertEqual(out[0].source.title, "Build tooling notes")
    }

    func testFetchesDocumentRecord() async throws {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v3/documents/docA")
            XCTAssertEqual(req.httpMethod, "GET")
            let json = #"{"id":"docA","content":"Full document text.","status":"done","title":"t","filepath":"/fixture.md"}"#
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
        let record = try await makeClient().document("docA")
        XCTAssertEqual(record, DocumentRecord(content: "Full document text.", filepath: "/fixture.md"))
    }

    func testMissingDocumentIsNil() async throws {
        StubURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }
        let record = try await makeClient().document("gone")
        XCTAssertNil(record)
    }

    func testDocumentChunkContainingFallsBackToWordOverlap() {
        let chunks = [
            DocumentChunk(id: "c0", position: 0, content: "PostgreSQL handles telemetry at scale."),
            DocumentChunk(id: "c1", position: 1, content: "MySQL backups are managed nightly."),
        ]
        XCTAssertNil(DocumentChunk.containing("oracle database", in: chunks))
        XCTAssertEqual(
            DocumentChunk.containing("telemetry PostgreSQL scale nightly", in: chunks)?.id,
            "c0",
            "word-overlap fallback when substring match fails")
    }

    func testNon200Throws() async {
        StubURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = makeClient()
        do {
            _ = try await client.search(SearchRequest(q: "x"))
            XCTFail("expected throw")
        } catch let e as EngineError {
            XCTAssertEqual(e, .httpStatus(500))
        } catch { XCTFail("wrong error \(error)") }
    }

    private func makeClient() -> EngineClient {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        return EngineClient(baseURL: URL(string: "http://127.0.0.1:6767")!,
                            apiKey: "sm_test",
                            session: URLSession(configuration: cfg))
    }
}

extension URLRequest {
    /// URLProtocol exposes POST bodies as a stream; drain it for assertions.
    func bodyStreamData() -> Data? {
        if let d = httpBody { return d }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufSize = 4096
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buf.deallocate() }
        while stream.hasBytesAvailable {
            let n = stream.read(buf, maxLength: bufSize)
            if n <= 0 { break }
            data.append(buf, count: n)
        }
        return data
    }
}

final class A209RegressionTests: XCTestCase {
    func testA209_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m209", memory: "Forgotten fact 209.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m209",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m209b", memory: "Active fact 209.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m209b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = QueryService.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m209b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA209_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e209", memory: "TTL fact 209.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e209",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(QueryService.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A238RegressionTests: XCTestCase {
    func testA238_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m238", memory: "Forgotten fact 238.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m238",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m238b", memory: "Active fact 238.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m238b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = QueryDecomposer.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m238b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA238_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e238", memory: "TTL fact 238.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e238",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(QueryDecomposer.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A267RegressionTests: XCTestCase {
    func testA267_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s267", memory: "Synthesis 267.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s267",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(CitationVerifier.dreamingSafeSynthesis("Synthesis 267.", existing: existing,
                                                      constituents: ["fact 267"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(CitationVerifier.dreamingSafeSynthesis("New synthesis 267.", existing: existing,
                                                     constituents: ["fact 267"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A122RegressionTests: XCTestCase {
    func testA122_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d122", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(SyncEngine.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(SyncEngine.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA122_unsupportedAnswerEvent() { XCTAssertEqual(SyncEngine.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)]) }
}
final class A180RegressionTests: XCTestCase { func testA180_x() { XCTAssertEqual(LLMHopPlanner.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }
final class A151RegressionTests: XCTestCase { func testA151_x() { XCTAssertEqual(ResponseStyle.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }

final class A93RegressionTests: XCTestCase {
    func testA93_lifecycleEventsRenderable() {
        let events = Confidence.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q93", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-035: PersonalRanker public API serves M4 evidence reranking.
final class PersonalRankerDocTests: XCTestCase {
    func testRankBoostsFrequentlyRetrievedSources() {
        let hits = [
            Retrieved(memory: "a", similarity: 0.6, source: .init(docId: "a", path: "/a", title: "a")),
            Retrieved(memory: "b", similarity: 0.7, source: .init(docId: "b", path: "/b", title: "b")),
        ]
        let ranked = PersonalRanker.rank(hits, strength: ["a": 10, "b": 1])
        XCTAssertEqual(ranked.first?.source.docId, "a")
    }
}
