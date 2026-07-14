import XCTest
@testable import MnemoDevServer

final class HTTPMessageTests: XCTestCase {

    func testParsesMethodPathQueryAndHeaders() {
        let raw = "GET /events?token=abc&x=1 HTTP/1.1\r\nHost: 127.0.0.1:7878\r\nAccept: text/event-stream\r\n\r\n"
        let req = HTTPRequest.parse(Data(raw.utf8))
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.method, "GET")
        XCTAssertEqual(req?.path, "/events")
        XCTAssertEqual(req?.query["token"], "abc")
        XCTAssertEqual(req?.query["x"], "1")
        XCTAssertEqual(req?.header("accept"), "text/event-stream")
    }

    func testParsesPostBody() {
        let raw = "POST /api/ask HTTP/1.1\r\nContent-Length: 15\r\n\r\n{\"query\":\"hi\"}"
        let req = HTTPRequest.parse(Data(raw.utf8))
        XCTAssertEqual(req?.method, "POST")
        XCTAssertEqual(req?.path, "/api/ask")
        XCTAssertEqual(req.map { String(data: $0.body, encoding: .utf8) }, "{\"query\":\"hi\"}")
    }

    func testHeaderLookupIsCaseInsensitive() {
        let raw = "GET / HTTP/1.1\r\nX-Mnemo-Token: sekret\r\n\r\n"
        let req = HTTPRequest.parse(Data(raw.utf8))
        XCTAssertEqual(req?.header("x-mnemo-token"), "sekret")
        XCTAssertEqual(req?.header("X-MNEMO-TOKEN"), "sekret")
    }

    func testMalformedReturnsNil() {
        XCTAssertNil(HTTPRequest.parse(Data("garbage-with-no-crlfcrlf".utf8)))
    }

    func testResponseSerializesStatusLineAndContentLength() {
        let resp = HTTPResponse.json(Data("{}".utf8))
        let out = String(data: resp.serialize(), encoding: .utf8)!
        XCTAssertTrue(out.hasPrefix("HTTP/1.1 200 OK\r\n"), out)
        XCTAssertTrue(out.contains("Content-Length: 2\r\n"), out)
        XCTAssertTrue(out.hasSuffix("\r\n\r\n{}"), out)
    }
}
