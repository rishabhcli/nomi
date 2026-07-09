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
