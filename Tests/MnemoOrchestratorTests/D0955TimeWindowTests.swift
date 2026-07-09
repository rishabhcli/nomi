import XCTest
@testable import MnemoOrchestrator

/// D-0955: egress guard host parsing for TimeWindow (seed 59b38ffb1848).
final class D0955TimeWindowTests: XCTestCase {
    private let seed = "59b38ffb1848"
    func testEgressHostParsing_rng() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
    }

}
