import XCTest
@testable import MnemoOrchestrator

/// D-0564: offline refusal paths for RouterEscalator (seed ebda66d7614c).
final class D0564RouterEscalatorTests: XCTestCase {
    private let seed = "ebda66d7614c"

    func testOffline_refusalEventsRenderable() {
        let events = RouterEscalator.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }

    func testOffline_phase2RefusalPath() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }

    func testOffline_noCloudHostsInPoisonCheck() {
        XCTAssertFalse(RouterEscalator.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(RouterEscalator.resistsCachePoisoning("127.0.0.1"))
    }
}
