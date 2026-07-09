import XCTest
@testable import MnemoOrchestrator

/// D-0924: offline refusal paths for EngineIntegration (seed 40cd374d228e).
final class D0924EngineIntegrationTests: XCTestCase {
    private let seed = "40cd374d228e"
    func testOfflineRefusal_rng() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
        XCTAssertFalse(QueryService.offlineRefusalEvents().isEmpty)
    }

}
