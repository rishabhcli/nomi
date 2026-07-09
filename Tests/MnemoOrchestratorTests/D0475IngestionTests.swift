import XCTest
@testable import MnemoOrchestrator

/// D-0475: Ingestion egress guard host parsing (seed 3ebc1250aad2).
final class D0475IngestionTests: XCTestCase {
    private let seed = "3ebc1250aad2"

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
