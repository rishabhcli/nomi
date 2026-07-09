import XCTest
@testable import MnemoOrchestrator

/// D-0815: egress guard host parsing for Highlight (seed 5d94ac47dde1).
final class D0815HighlightTests: XCTestCase {
    private let seed = "5d94ac47dde1"
    func testEgressHostParsing_rng() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
    }

}
