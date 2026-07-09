import XCTest
@testable import MnemoOrchestrator

/// D-0555: egress guard host parsing for MediaCompanion (seed db1cbe4b017b).
final class D0555MediaCompanionTests: XCTestCase {
    private let seed = "db1cbe4b017b"

    func testEgress_hostParsingSafe() {
        XCTAssertTrue(MediaCompanion.egressHostParsingSafe())
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
