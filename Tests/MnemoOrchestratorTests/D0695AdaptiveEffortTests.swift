import XCTest
@testable import MnemoOrchestrator

/// D-0695: egress guard host parsing for AdaptiveEffort (seed d49f92c4799c).
final class D0695AdaptiveEffortTests: XCTestCase {
    private let seed = "d49f92c4799c"

    func testEgress_hostParsingSafe() {
        XCTAssertTrue(AdaptiveEffort.egressHostParsingSafe())
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
