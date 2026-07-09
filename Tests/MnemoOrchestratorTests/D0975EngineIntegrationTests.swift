import XCTest
@testable import MnemoOrchestrator

/// D-0975: egress guard host parsing for EngineIntegration (seed 00a514fb71b7).
final class D0975EngineIntegrationTests: XCTestCase {
    private let seed = "00a514fb71b7"
    func testEgressHostParsing_rng() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
    }

}
