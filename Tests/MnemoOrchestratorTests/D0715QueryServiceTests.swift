import XCTest
@testable import MnemoOrchestrator

/// D-0715: egress guard host parsing for QueryService (seed 33ac23c6d985).
final class D0715QueryServiceTests: XCTestCase {
    private let seed = "33ac23c6d985"

    func testEgress_hostParsingSafe() {
        XCTAssertTrue(QueryService.egressHostParsingSafe())
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
