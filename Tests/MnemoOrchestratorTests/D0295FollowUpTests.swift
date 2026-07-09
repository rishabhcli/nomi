import XCTest
@testable import MnemoOrchestrator

/// D-0295: FollowUp egress guard host parsing (seed 14dc70141c0e).
final class D0295FollowUpTests: XCTestCase {
    private let seed = "14dc70141c0e"

    func testLoopbackHostsAllowed() {
        Phase2TechniqueSupport.assertLoopbackOnly("127.0.0.1")
        Phase2TechniqueSupport.assertLoopbackOnly("localhost")
        Phase2TechniqueSupport.assertNonLoopback("127.0.0.1.evil.com")
    }

    func testActionExtractorLoopbackOnly() {
        XCTAssertTrue(ActionExtractor.actionHostIsLoopback("http://127.0.0.1:6767/doc"))
        XCTAssertFalse(ActionExtractor.actionHostIsLoopback("https://api.supermemory.ai/x"))
    }

    func testProperty_hostClassificationDeterministic() {
        var rng = Phase2RNG(seed: seed)
        let hosts = ["127.0.0.1", "localhost", "10.0.0.1", "127.0.0.1.evil.com"]
        for _ in 0..<8 {
            let h = hosts[rng.nextInt(upperBound: hosts.count)]
            XCTAssertEqual(EgressGuard.isLoopbackHost(h), EgressGuard.isLoopbackHost(h))
        }
    }
}
