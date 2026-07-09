import XCTest
@testable import MnemoOrchestrator

/// D-0995: egress guard host parsing for EgressGuard (seed d1a0ef5368a9).
final class D0995EgressGuardTests: XCTestCase {
    private let seed = "d1a0ef5368a9"
    func testEgressHostParsing_rng() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
    }

}
