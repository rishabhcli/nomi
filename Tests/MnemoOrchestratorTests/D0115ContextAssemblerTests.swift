import XCTest
@testable import MnemoOrchestrator

/// D-0115: ContextAssembler egress guard host parsing (seed bedfeb5aa6b8).
final class D0115ContextAssemblerTests: XCTestCase {
    private let seed = "bedfeb5aa6b8"

    func testParsesLoopbackHost() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(ContextAssembler.egressHostParsingSafe())
    }
}
