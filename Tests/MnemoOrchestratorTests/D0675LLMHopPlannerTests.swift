import XCTest
@testable import MnemoOrchestrator

/// D-0675: egress guard host parsing for LLMHopPlanner (seed 5c38e2d3ba2a).
final class D0675LLMHopPlannerTests: XCTestCase {
    private let seed = "5c38e2d3ba2a"

    func testEgress_hostParsingSafe() {
        XCTAssertTrue(LLMHopPlanner.egressHostParsingSafe())
    }

    func testEgress_loopbackOnly() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
    }

    func testEgress_phase2Parse() {
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
        XCTAssertFalse(Phase2Techniques.parseHostForEgress("example.com"))
    }
}
