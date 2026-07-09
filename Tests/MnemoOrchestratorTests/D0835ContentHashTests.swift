import XCTest
@testable import MnemoOrchestrator

/// D-0835: egress guard host parsing for ContentHash (seed a6adb45a1f82).
final class D0835ContentHashTests: XCTestCase {
    private let seed = "a6adb45a1f82"
    func testEgressHostParsing_rng() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
    }

}
