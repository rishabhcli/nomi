import XCTest
@testable import MnemoOrchestrator

/// D-0775: egress guard host parsing for AgenticGrep (seed 052e0c232a2d).
final class D0775AgenticGrepTests: XCTestCase {
    private let seed = "052e0c232a2d"
    func testEgressHostParsing_rng() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
    }

}
