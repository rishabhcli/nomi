import XCTest
@testable import MnemoOrchestrator

/// D-0935: egress guard host parsing for IngestGate (seed 810ba5032a3d).
final class D0935IngestGateTests: XCTestCase {
    private let seed = "810ba5032a3d"
    func testEgressHostParsing_rng() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
    }

}
