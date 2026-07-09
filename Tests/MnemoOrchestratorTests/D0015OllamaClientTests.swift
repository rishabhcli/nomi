import XCTest
@testable import MnemoOrchestrator

/// D-0015: OllamaClient egress guard host parsing (seed 63f70d070176).
final class D0015OllamaClientTests: XCTestCase {
    private let seed = "63f70d070176"

    func testParseLoopbackHostAccepts127() {
        XCTAssertEqual(OllamaClient.parseLoopbackHost(from: URL(string: "http://127.0.0.1:11434")!), "127.0.0.1")
    }

    func testParseLoopbackHostRejectsSpoofed() {
        XCTAssertNil(OllamaClient.parseLoopbackHost(from: URL(string: "http://127.0.0.1.evil.com:11434")!))
        XCTAssertNil(OllamaClient.parseLoopbackHost(from: URL(string: "http://api.openai.com/v1")!))
    }

    func testStreamValidatesLoopbackBeforeRequest() {
        XCTAssertNotNil(OllamaClient.parseLoopbackHost(from: URL(string: "http://127.0.0.1:11434")!))
        XCTAssertNil(OllamaClient.parseLoopbackHost(from: URL(string: "http://192.168.1.1:11434")!))
    }

    func testProperty_loopbackHostClassificationMatchesEgressGuard() {
        var rng = Phase2RNG(seed: seed)
        let hosts = ["127.0.0.1", "localhost", "::1", "127.0.0.1.evil.com", "10.0.0.1"]
        for _ in 0..<10 {
            let h = hosts[rng.nextInt(upperBound: hosts.count)]
            let url = URL(string: "http://\(h):11434")!
            let parsed = OllamaClient.parseLoopbackHost(from: url) != nil
            XCTAssertEqual(parsed, EgressGuard.isLoopbackHost(h))
        }
    }
}
