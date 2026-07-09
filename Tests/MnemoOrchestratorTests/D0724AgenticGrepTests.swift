import XCTest
@testable import MnemoOrchestrator

/// D-0724: offline refusal paths for AgenticGrep (seed 96cb571064ea).
final class D0724AgenticGrepTests: XCTestCase {
    private let seed = "96cb571064ea"

    func testOffline_refusalEventsRenderable() {
        let events = AgenticGrep.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }

    func testOffline_phase2RefusalPath() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }

    func testOffline_noCloudHostsInPoisonCheck() {
        XCTAssertFalse(AgenticGrep.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(AgenticGrep.resistsCachePoisoning("127.0.0.1"))
    }
}
