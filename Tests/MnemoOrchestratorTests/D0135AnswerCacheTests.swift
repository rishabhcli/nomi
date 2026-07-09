import XCTest
@testable import MnemoOrchestrator

/// D-0135: AnswerCache egress guard host parsing (seed 04a2ee6a36d3).
final class D0135AnswerCacheTests: XCTestCase {
    private let seed = "04a2ee6a36d3"

    func testParsesLoopbackHost() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(AnswerCache.egressHostParsingSafe())
    }
}
