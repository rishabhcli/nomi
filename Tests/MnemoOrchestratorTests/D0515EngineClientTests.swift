import XCTest
@testable import MnemoOrchestrator

/// D-0515: egress guard host parsing for EngineClient (seed 9896ff5d8b3d).
final class D0515EngineClientTests: XCTestCase {
    private let seed = "9896ff5d8b3d"

    func testEgress_hostParsingSafe() {
        XCTAssertTrue(EngineClient.egressHostParsingSafe())
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
