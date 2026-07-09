import XCTest
@testable import MnemoOrchestrator

/// D-0544: offline refusal paths for QueryHistory (seed 73c60d5e3b40).
final class D0544QueryHistoryTests: XCTestCase {
    private let seed = "73c60d5e3b40"

    func testOffline_refusalEventsRenderable() {
        let events = QueryHistory.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }

    func testOffline_phase2RefusalPath() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }

    func testOffline_noCloudHostsInPoisonCheck() {
        XCTAssertFalse(QueryHistory.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(QueryHistory.resistsCachePoisoning("127.0.0.1"))
    }
}
