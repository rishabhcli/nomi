import XCTest
@testable import MnemoOrchestrator

/// D-0075: Inspector egress guard host parsing (seed f09f2fb7eb3c).
final class D0075InspectorTests: XCTestCase {
    private let seed = "f09f2fb7eb3c"

    func testParsesLoopbackHost() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Inspector.egressHostParsingSafe())
    }
}
