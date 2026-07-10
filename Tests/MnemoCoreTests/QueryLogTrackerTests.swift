import XCTest
@testable import MnemoCore

final class QueryLogTrackerTests: XCTestCase {
    func testTrackerEmitsAllFacets() async {
        var tracker = QueryLogTracker(queryId: "q-test", modelId: "gpt-oss:20b")
        tracker.noteRouted(intent: "synthesis", effort: "medium")
        tracker.noteFirstToken()
        tracker.noteReasoningStep()
        tracker.noteCitation(supported: true)
        tracker.noteCitation(supported: false)
        tracker.noteContextTokens(4000)
        tracker.noteTerminal("answered")

        let sink = InMemoryQueryLogSink()
        await tracker.emit(to: sink, egressBlockedCount: 0)
        let entry = await sink.last()
        XCTAssertEqual(entry?.queryId, "q-test")
        XCTAssertEqual(entry?.routeIntent, "synthesis")
        XCTAssertEqual(entry?.modelId, "gpt-oss:20b")
        XCTAssertNotNil(entry?.firstTokenMs)
        XCTAssertNotNil(entry?.totalMs)
        XCTAssertEqual(entry?.retrievalHopCount, 1)
        XCTAssertEqual(entry?.egressBlockedCount, 0)
        XCTAssertEqual(entry?.contextTokenCount, 4000)
        XCTAssertEqual(entry?.terminalState, "answered")
        XCTAssertEqual(entry?.verificationPassRate ?? -1, 0.5, accuracy: 0.01)
    }

    func testRedactedEntryExcludesLongDocumentText() throws {
        let doc = String(repeating: "secret document body ", count: 50)
        var entry = QueryLogEntry()
        entry.routeIntent = LogRotation.sanitizeInfo(doc)
        let line = try entry.jsonLine()
        XCTAssertFalse(line.contains(String(repeating: "secret", count: 20)))
        XCTAssertTrue(line.contains("…"))
    }
}
