import XCTest
@testable import MnemoSupervisor

final class LoopbackAuditTests: XCTestCase {
    static let fixture = """
    COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
    ollama    501 m3     8u  IPv4  0x1      0t0  TCP 127.0.0.1:11434 (LISTEN)
    supermem  502 m3    10u  IPv4  0x2      0t0  TCP 127.0.0.1:6767 (LISTEN)
    rogue     503 m3    11u  IPv4  0x3      0t0  TCP 0.0.0.0:8080 (LISTEN)
    """
    func testParsesSockets() {
        let s = LoopbackAudit.parseLSOF(Self.fixture)
        XCTAssertEqual(s.count, 3)
        XCTAssertEqual(s[0], ListeningSocket(command: "ollama", pid: 501, address: "127.0.0.1:11434"))
    }
    func testFlagsNonLoopback() {
        let bad = LoopbackAudit.nonLoopback(LoopbackAudit.parseLSOF(Self.fixture))
        XCTAssertEqual(bad.map(\.address), ["0.0.0.0:8080"])
    }
    func testIPv6LoopbackAccepted() {
        let v6 = """
        COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
        engine    600 m3    12u  IPv6  0x4      0t0  TCP [::1]:6767 (LISTEN)
        """
        XCTAssertTrue(LoopbackAudit.nonLoopback(LoopbackAudit.parseLSOF(v6)).isEmpty)
    }
    func testWildcardListenerParsedAndFlagged() {
        // Real lsof prints `*:8080` for a 0.0.0.0 / [::] bind. Dropping that
        // line would produce a false "loopback OK" — the audit must flag it.
        let wild = """
        COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
        rogue     504 m3    12u  IPv4  0x5      0t0  TCP *:8080 (LISTEN)
        """
        let sockets = LoopbackAudit.parseLSOF(wild)
        XCTAssertEqual(sockets, [ListeningSocket(command: "rogue", pid: 504, address: "*:8080")])
        XCTAssertEqual(LoopbackAudit.nonLoopback(sockets).map(\.address), ["*:8080"])
    }
}
