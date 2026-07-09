import XCTest
@testable import MnemoOrchestrator

/// D-0584: offline refusal paths for LLMSynthesizer (seed 377d8ccd839f).
final class D0584LLMSynthesizerTests: XCTestCase {
    private let seed = "377d8ccd839f"

    func testOffline_refusalEventsRenderable() {
        let events = LLMSynthesizer.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }

    func testOffline_phase2RefusalPath() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }

    func testOffline_noCloudHostsInPoisonCheck() {
        XCTAssertFalse(LLMSynthesizer.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(LLMSynthesizer.resistsCachePoisoning("127.0.0.1"))
    }
}
