import XCTest
@testable import MnemoOrchestrator

/// D-0575: egress guard host parsing for Prompt (seed 3dd8e6fa29c7).
final class D0575PromptTests: XCTestCase {
    private let seed = "3dd8e6fa29c7"

    func testEgress_hostParsingSafe() {
        XCTAssertTrue(Prompt.egressHostParsingSafe())
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
