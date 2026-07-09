import XCTest
@testable import MnemoOrchestrator

/// D-0235: ScopeClassifier egress guard host parsing (seed 5d1706cf41ee).
final class D0235ScopeClassifierTests: XCTestCase {
    private let seed = "5d1706cf41ee"

    func testParsesLoopbackHost() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(ScopeClassifier.egressHostParsingSafe())
    }
}
