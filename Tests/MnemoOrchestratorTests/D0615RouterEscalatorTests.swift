import XCTest
@testable import MnemoOrchestrator

/// D-0615: egress guard host parsing for RouterEscalator (seed a2bfd1d839d3).
final class D0615RouterEscalatorTests: XCTestCase {
    private let seed = "a2bfd1d839d3"

    func testEgress_hostParsingSafe() {
        XCTAssertTrue(RouterEscalator.egressHostParsingSafe())
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
