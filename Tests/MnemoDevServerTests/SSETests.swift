import XCTest
@testable import MnemoDevServer

final class SSETests: XCTestCase {

    func testFrameWithEventAndId() {
        let f = SSE.frame(event: "trace", data: "{\"a\":1}", id: "5")
        XCTAssertEqual(f, "event: trace\nid: 5\ndata: {\"a\":1}\n\n")
    }

    func testFrameDataOnly() {
        XCTAssertEqual(SSE.frame(event: nil, data: "hello"), "data: hello\n\n")
    }

    func testFrameMultilineDataPrefixesEachLine() {
        XCTAssertEqual(SSE.frame(event: nil, data: "a\nb"), "data: a\ndata: b\n\n")
    }

    func testComment() {
        XCTAssertEqual(SSE.comment("ping"), ": ping\n\n")
    }
}
