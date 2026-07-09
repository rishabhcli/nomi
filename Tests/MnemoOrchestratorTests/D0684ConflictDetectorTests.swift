import XCTest
@testable import MnemoOrchestrator

/// D-0684: offline refusal paths for ConflictDetector (seed 7540c42e2b06).
final class D0684ConflictDetectorTests: XCTestCase {
    private let seed = "7540c42e2b06"

    func testOffline_refusalEventsRenderable() {
        let events = ConflictDetector.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }

    func testOffline_phase2RefusalPath() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }

    func testOffline_noCloudHostsInPoisonCheck() {
        XCTAssertFalse(ConflictDetector.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(ConflictDetector.resistsCachePoisoning("127.0.0.1"))
    }
}
