import XCTest
@testable import MnemoOrchestrator

/// D-0744: offline refusal paths for QueryDecomposer (seed 731d38b0c19d).
final class D0744QueryDecomposerTests: XCTestCase {
    private let seed = "731d38b0c19d"

    func testOffline_refusalEventsRenderable() {
        let events = QueryDecomposer.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }

    func testOffline_phase2RefusalPath() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }

    func testOffline_noCloudHostsInPoisonCheck() {
        XCTAssertFalse(QueryDecomposer.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(QueryDecomposer.resistsCachePoisoning("127.0.0.1"))
    }
}
