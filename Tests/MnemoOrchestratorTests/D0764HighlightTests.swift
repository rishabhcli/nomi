import XCTest
@testable import MnemoOrchestrator

/// D-0764: offline refusal paths for Highlight (seed c00516f815fd).
final class D0764HighlightTests: XCTestCase {
    private let seed = "c00516f815fd"
    func testOfflineRefusal_rng() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
        XCTAssertFalse(QueryService.offlineRefusalEvents().isEmpty)
    }

}
