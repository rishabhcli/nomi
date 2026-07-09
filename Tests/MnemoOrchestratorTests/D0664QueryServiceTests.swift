import XCTest
@testable import MnemoOrchestrator

/// D-0664: offline refusal paths for QueryService (seed 056facebd0cf).
final class D0664QueryServiceTests: XCTestCase {
    private let seed = "056facebd0cf"

    func testOffline_refusalEventsRenderable() {
        let events = QueryService.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }

    func testOffline_phase2RefusalPath() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }

    func testOffline_noCloudHostsInPoisonCheck() {
        XCTAssertFalse(QueryService.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(QueryService.resistsCachePoisoning("127.0.0.1"))
    }
}
