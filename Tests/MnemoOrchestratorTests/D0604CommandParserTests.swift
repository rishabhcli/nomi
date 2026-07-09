import XCTest
@testable import MnemoOrchestrator

/// D-0604: offline refusal paths for CommandParser (seed f5976170ef0d).
final class D0604CommandParserTests: XCTestCase {
    private let seed = "f5976170ef0d"

    func testOffline_refusalEventsRenderable() {
        let events = CommandParser.offlineRefusalEvents()
        XCTAssertTrue(Phase2TestSupport.isRenderable(events))
    }

    func testOffline_phase2RefusalPath() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
    }

    func testOffline_noCloudHostsInPoisonCheck() {
        XCTAssertFalse(CommandParser.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(CommandParser.resistsCachePoisoning("127.0.0.1"))
    }

    func testParse_slashCommands() {
        XCTAssertEqual(CommandParser.parse("/help"), .command(.help))
        XCTAssertEqual(CommandParser.parse("plain query"), .query("plain query"))
    }
}
