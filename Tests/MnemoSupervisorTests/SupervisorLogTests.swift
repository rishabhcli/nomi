import XCTest
@testable import MnemoSupervisor

final class SupervisorLogTests: XCTestCase {
    func testCollectEmptyWhenNoLogs() {
        let bundle = SupervisorLogAggregator.collect(maxLines: 5)
        XCTAssertEqual(bundle.supervisorLines, [])
        XCTAssertFalse(bundle.timestamp.isEmpty)
    }

    func testBundleEncodesJSON() throws {
        let bundle = SupervisorLogAggregator.Bundle(
            supervisorLines: ["start ollama"],
            engineLines: [],
            appJSONLLines: ["{\"queryId\":\"q1\"}"],
            timestamp: "2026-07-09T12:00:00Z")
        let line = try bundle.jsonLine()
        XCTAssertTrue(line.contains("supervisorLines"))
        XCTAssertTrue(line.contains("q1"))
    }
}
