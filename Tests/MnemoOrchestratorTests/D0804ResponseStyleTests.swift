import XCTest
@testable import MnemoOrchestrator

/// D-0804: offline refusal paths for ResponseStyle (seed 8a4eacc7e540).
final class D0804ResponseStyleTests: XCTestCase {
    private let seed = "8a4eacc7e540"
    func testOfflineRefusal_rng() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
        XCTAssertFalse(QueryService.offlineRefusalEvents().isEmpty)
    }

}
