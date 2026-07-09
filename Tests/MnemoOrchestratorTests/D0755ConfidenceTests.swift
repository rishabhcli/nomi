import XCTest
@testable import MnemoOrchestrator

/// D-0755: egress guard host parsing for Confidence (seed f3255f1e6796).
final class D0755ConfidenceTests: XCTestCase {
    private let seed = "f3255f1e6796"
    func testEgressHostParsing_rng() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
    }

}
