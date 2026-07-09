import XCTest
@testable import MnemoOrchestrator

/// D-0155: Router egress guard host parsing (seed 9deab5944d06).
final class D0155RouterTests: XCTestCase {
    private let seed = "9deab5944d06"

    func testParsesLoopbackHost() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Router.egressHostParsingSafe())
    }
}
