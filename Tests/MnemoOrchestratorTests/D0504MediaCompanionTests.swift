import XCTest
@testable import MnemoOrchestrator

/// D-0504: offline refusal paths for MediaCompanion (seed ed847090523e).
final class D0504MediaCompanionTests: XCTestCase {
    private let seed = "ed847090523e"

    func testOffline_refusalEventsRenderable() {
        let events = MediaCompanion.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }

    func testOffline_phase2RefusalPath() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }

    func testOffline_noCloudHostsInPoisonCheck() {
        XCTAssertFalse(MediaCompanion.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(MediaCompanion.resistsCachePoisoning("127.0.0.1"))
    }
}
