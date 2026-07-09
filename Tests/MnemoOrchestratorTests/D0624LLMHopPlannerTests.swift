import XCTest
@testable import MnemoOrchestrator

/// D-0624: offline refusal paths for LLMHopPlanner (seed 16ff54a74e04).
final class D0624LLMHopPlannerTests: XCTestCase {
    private let seed = "16ff54a74e04"

    func testOffline_refusalEventsRenderable() {
        let events = LLMHopPlanner.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }

    func testOffline_phase2RefusalPath() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }

    func testOffline_noCloudHostsInPoisonCheck() {
        XCTAssertFalse(LLMHopPlanner.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(LLMHopPlanner.resistsCachePoisoning("127.0.0.1"))
    }
}
