import XCTest
@testable import MnemoOrchestrator

/// D-0175: Consolidation egress guard host parsing (seed 8a6e1b22129a).
final class D0175ConsolidationTests: XCTestCase {
    private let seed = "8a6e1b22129a"

    func testParsesLoopbackHost() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Consolidation.egressHostParsingSafe())
    }
}
