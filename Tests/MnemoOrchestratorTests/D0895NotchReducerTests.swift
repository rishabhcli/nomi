import XCTest
@testable import MnemoOrchestrator

/// D-0895: egress guard host parsing for NotchReducer (seed 8272359b270c).
final class D0895NotchReducerTests: XCTestCase {
    private let seed = "8272359b270c"
    func testEgressHostParsing_rng() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
    }

}
