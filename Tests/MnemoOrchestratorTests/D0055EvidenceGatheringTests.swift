import XCTest
@testable import MnemoOrchestrator

/// D-0055: EvidenceGathering egress guard host parsing (seed b208ce604b7a).
final class D0055EvidenceGatheringTests: XCTestCase {
    private let seed = "b208ce604b7a"

    func testParsesLoopbackHost() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(EvidenceGathering.egressHostParsingSafe())
    }
}
