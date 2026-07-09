import XCTest
@testable import MnemoOrchestrator

/// D-0535: egress guard host parsing for Profile (seed 0201e29d6635).
final class D0535ProfileTests: XCTestCase {
    private let seed = "0201e29d6635"

    func testEgress_hostParsingSafe() {
        XCTAssertTrue(Profile.egressHostParsingSafe())
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
