import XCTest
@testable import MnemoOrchestrator

/// D-0855: egress guard host parsing for ResponseStyle (seed 5bf7850eb981).
final class D0855ResponseStyleTests: XCTestCase {
    private let seed = "5bf7850eb981"
    func testEgressHostParsing_rng() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
    }

}
