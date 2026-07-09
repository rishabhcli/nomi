import XCTest
@testable import MnemoOrchestrator

/// D-0195: Provenance egress guard host parsing (seed c4adea3620ca).
final class D0195ProvenanceTests: XCTestCase {
    private let seed = "c4adea3620ca"

    func testParsesLoopbackHost() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Provenance.egressHostParsingSafe())
    }
}
