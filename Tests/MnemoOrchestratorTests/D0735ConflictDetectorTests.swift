import XCTest
@testable import MnemoOrchestrator

/// D-0735: egress guard host parsing for ConflictDetector (seed 243b7a265182).
final class D0735ConflictDetectorTests: XCTestCase {
    private let seed = "243b7a265182"

    func testEgress_hostParsingSafe() {
        XCTAssertTrue(ConflictDetector.egressHostParsingSafe())
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
