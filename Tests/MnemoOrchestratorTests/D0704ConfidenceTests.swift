import XCTest
@testable import MnemoOrchestrator

/// D-0704: offline refusal paths for Confidence (seed d11bbeb5195b).
final class D0704ConfidenceTests: XCTestCase {
    private let seed = "d11bbeb5195b"

    func testOffline_refusalEventsRenderable() {
        let events = Confidence.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }

    func testOffline_phase2RefusalPath() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }

    func testOffline_noCloudHostsInPoisonCheck() {
        XCTAssertFalse(Confidence.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(Confidence.resistsCachePoisoning("127.0.0.1"))
    }
}
