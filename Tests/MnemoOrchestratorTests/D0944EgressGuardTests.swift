import XCTest
@testable import MnemoOrchestrator

/// D-0944: offline refusal paths for EgressGuard (seed 499989ba2136).
final class D0944EgressGuardTests: XCTestCase {
    private let seed = "499989ba2136"
    func testOfflineRefusal_rng() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
        XCTAssertFalse(QueryService.offlineRefusalEvents().isEmpty)
    }

}
