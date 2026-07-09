import XCTest
@testable import MnemoOrchestrator

/// D-0524: offline refusal paths for Prompt (seed a6d2bf653e4a).
final class D0524PromptTests: XCTestCase {
    private let seed = "a6d2bf653e4a"

    func testOffline_refusalEventsRenderable() {
        let events = Prompt.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }

    func testOffline_phase2RefusalPath() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }

    func testOffline_noCloudHostsInPoisonCheck() {
        XCTAssertFalse(Prompt.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(Prompt.resistsCachePoisoning("127.0.0.1"))
    }
}
