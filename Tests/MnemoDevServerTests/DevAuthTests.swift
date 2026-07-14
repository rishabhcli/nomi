import XCTest
@testable import MnemoDevServer

/// The dev server drives the real orchestrator, so auth matters even on
/// loopback: a session token blocks other local processes, and an Origin/Host
/// loopback check blocks a visited webpage from POSTing to 127.0.0.1 (CSRF).
final class DevAuthTests: XCTestCase {

    private func parse(_ raw: String) -> HTTPRequest { HTTPRequest.parse(Data(raw.utf8))! }

    func testNewTokenIsLongAndUnique() {
        let a = DevAuth.newToken()
        let b = DevAuth.newToken()
        XCTAssertGreaterThanOrEqual(a.count, 32)
        XCTAssertNotEqual(a, b)
    }

    func testAuthorizedWithQueryToken() {
        let r = parse("GET /events?token=abc HTTP/1.1\r\nHost: 127.0.0.1:7878\r\n\r\n")
        XCTAssertTrue(DevAuth.isAuthorized(r, token: "abc"))
    }

    func testAuthorizedWithHeaderToken() {
        let r = parse("POST /api/ask HTTP/1.1\r\nHost: 127.0.0.1:7878\r\nX-Mnemo-Token: abc\r\n\r\n{}")
        XCTAssertTrue(DevAuth.isAuthorized(r, token: "abc"))
    }

    func testRejectsWrongOrMissingToken() {
        let wrong = parse("GET /events?token=nope HTTP/1.1\r\nHost: 127.0.0.1:7878\r\n\r\n")
        XCTAssertFalse(DevAuth.isAuthorized(wrong, token: "abc"))
        let missing = parse("GET /events HTTP/1.1\r\nHost: 127.0.0.1:7878\r\n\r\n")
        XCTAssertFalse(DevAuth.isAuthorized(missing, token: "abc"))
    }

    func testRejectsEmptyServerToken() {
        let r = parse("GET /events?token= HTTP/1.1\r\nHost: 127.0.0.1:7878\r\n\r\n")
        XCTAssertFalse(DevAuth.isAuthorized(r, token: ""))
    }

    func testRejectsNonLoopbackOrigin() {
        let r = parse("POST /api/ask HTTP/1.1\r\nHost: 127.0.0.1:7878\r\nOrigin: http://evil.example\r\nX-Mnemo-Token: abc\r\n\r\n{}")
        XCTAssertFalse(DevAuth.isAuthorized(r, token: "abc"), "a non-loopback Origin must be rejected even with a valid token")
    }

    func testAllowsAbsentOrigin() {
        let r = parse("GET /events?token=abc HTTP/1.1\r\nHost: 127.0.0.1:7878\r\n\r\n")
        XCTAssertTrue(DevAuth.isAuthorized(r, token: "abc"))
    }

    func testAllowsLoopbackOrigin() {
        let r = parse("POST /api/ask HTTP/1.1\r\nHost: 127.0.0.1:7878\r\nOrigin: http://127.0.0.1:7878\r\nX-Mnemo-Token: abc\r\n\r\n{}")
        XCTAssertTrue(DevAuth.isAuthorized(r, token: "abc"))
    }
}
