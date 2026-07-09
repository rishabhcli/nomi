import XCTest
@testable import MnemoOrchestrator

/// D-0635: egress guard host parsing for LLMSynthesizer (seed 4ee05c3f3785).
final class D0635LLMSynthesizerTests: XCTestCase {
    private let seed = "4ee05c3f3785"

    func testEgress_hostParsingSafe() {
        XCTAssertTrue(LLMSynthesizer.egressHostParsingSafe())
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
