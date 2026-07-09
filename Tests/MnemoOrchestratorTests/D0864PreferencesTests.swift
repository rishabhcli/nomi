import XCTest
@testable import MnemoOrchestrator

/// D-0864: offline refusal paths for Preferences (seed a24b94faec7c).
final class D0864PreferencesTests: XCTestCase {
    private let seed = "a24b94faec7c"
    func testOfflineRefusal_rng() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
        XCTAssertFalse(QueryService.offlineRefusalEvents().isEmpty)
    }

}
