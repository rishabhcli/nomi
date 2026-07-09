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
