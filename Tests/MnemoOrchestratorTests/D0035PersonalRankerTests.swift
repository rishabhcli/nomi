import XCTest
@testable import MnemoOrchestrator

/// D-0035: PersonalRanker egress guard host parsing (seed 60e4a06a8ace).
final class D0035PersonalRankerTests: XCTestCase {
    private let seed = "60e4a06a8ace"

    func testParsesLoopbackHost() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(PersonalRanker.egressHostParsingSafe())
    }
}
