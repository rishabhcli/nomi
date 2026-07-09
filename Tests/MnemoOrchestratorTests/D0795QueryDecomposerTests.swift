import XCTest
@testable import MnemoOrchestrator

/// D-0795: egress guard host parsing for QueryDecomposer (seed 05f4268a29d1).
final class D0795QueryDecomposerTests: XCTestCase {
    private let seed = "05f4268a29d1"
    func testEgressHostParsing_rng() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
    }

}
