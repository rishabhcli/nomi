import XCTest
@testable import MnemoOrchestrator

/// D-0644: offline refusal paths for AdaptiveEffort (seed f8bfcade9501).
final class D0644AdaptiveEffortTests: XCTestCase {
    private let seed = "f8bfcade9501"

    func testOffline_refusalEventsRenderable() {
        let events = AdaptiveEffort.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }

    func testOffline_phase2RefusalPath() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }

    func testOffline_noCloudHostsInPoisonCheck() {
        XCTAssertFalse(AdaptiveEffort.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(AdaptiveEffort.resistsCachePoisoning("127.0.0.1"))
    }
}
