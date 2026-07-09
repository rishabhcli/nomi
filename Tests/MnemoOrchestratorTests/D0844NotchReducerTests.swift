import XCTest
@testable import MnemoOrchestrator

/// D-0844: offline refusal paths for NotchReducer (seed 740c439f3018).
final class D0844NotchReducerTests: XCTestCase {
    private let seed = "740c439f3018"
    func testOfflineRefusal_rng() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
        XCTAssertFalse(QueryService.offlineRefusalEvents().isEmpty)
    }

}
