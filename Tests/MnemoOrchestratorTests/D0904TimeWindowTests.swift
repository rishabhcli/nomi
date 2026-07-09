import XCTest
@testable import MnemoOrchestrator

/// D-0904: offline refusal paths for TimeWindow (seed 5675b7d410bc).
final class D0904TimeWindowTests: XCTestCase {
    private let seed = "5675b7d410bc"
    func testOfflineRefusal_rng() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
        XCTAssertFalse(QueryService.offlineRefusalEvents().isEmpty)
    }

}
