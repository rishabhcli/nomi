import XCTest
@testable import MnemoOrchestrator

/// D-0884: offline refusal paths for IngestGate (seed 14037d744ec5).
final class D0884IngestGateTests: XCTestCase {
    private let seed = "14037d744ec5"
    func testOfflineRefusal_rng() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
        XCTAssertFalse(QueryService.offlineRefusalEvents().isEmpty)
    }

}
