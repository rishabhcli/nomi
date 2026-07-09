import XCTest
@testable import MnemoOrchestrator

/// D-0595: egress guard host parsing for QueryHistory (seed 946d648d569e).
final class D0595QueryHistoryTests: XCTestCase {
    private let seed = "946d648d569e"

    func testEgress_hostParsingSafe() {
        XCTAssertTrue(QueryHistory.egressHostParsingSafe())
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
