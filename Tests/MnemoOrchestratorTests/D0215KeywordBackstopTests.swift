import XCTest
@testable import MnemoOrchestrator

/// D-0215: KeywordBackstop egress guard host parsing (seed 113dd69aa635).
final class D0215KeywordBackstopTests: XCTestCase {
    private let seed = "113dd69aa635"

    func testParsesLoopbackHost() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(KeywordBackstop.egressHostParsingSafe())
    }
}
