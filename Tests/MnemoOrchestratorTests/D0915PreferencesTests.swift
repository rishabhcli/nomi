import XCTest
@testable import MnemoOrchestrator

/// D-0915: egress guard host parsing for Preferences (seed b4bf70f82c30).
final class D0915PreferencesTests: XCTestCase {
    private let seed = "b4bf70f82c30"
    func testEgressHostParsing_rng() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
    }

}
