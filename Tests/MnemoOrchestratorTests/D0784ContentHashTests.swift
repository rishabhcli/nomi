import XCTest
@testable import MnemoOrchestrator

/// D-0784: offline refusal paths for ContentHash (seed 4d8c731fd055).
final class D0784ContentHashTests: XCTestCase {
    private let seed = "4d8c731fd055"
    func testOfflineRefusal_rng() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
        XCTAssertFalse(QueryService.offlineRefusalEvents().isEmpty)
    }

}
