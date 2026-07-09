import XCTest
@testable import MnemoOrchestrator

/// D-0095: EntityExtractor egress guard host parsing (seed 81c00e788461).
final class D0095EntityExtractorTests: XCTestCase {
    private let seed = "81c00e788461"

    func testParsesLoopbackHost() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(EntityExtractor.egressHostParsingSafe())
    }
}
