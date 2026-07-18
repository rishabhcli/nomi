import XCTest
@testable import MnemoCore

final class StructuredLogTests: XCTestCase {
    func testAppendLineRestrictsLogDirectoryAndFilePermissions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mnemo-structured-log-\(UUID().uuidString)", isDirectory: true)
        let logsDir = root.appendingPathComponent("Logs", isDirectory: true)
        let log = logsDir.appendingPathComponent("app.jsonl")
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: logsDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o777]
        )

        MnemoLogPaths.appendLine("first\n", to: log.path)

        XCTAssertEqual(try posixPermissions(at: logsDir), 0o700)
        XCTAssertEqual(try posixPermissions(at: log), 0o600)

        try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: log.path)
        MnemoLogPaths.appendLine("second\n", to: log.path)

        XCTAssertEqual(try posixPermissions(at: log), 0o600)
        XCTAssertEqual(try String(contentsOf: log, encoding: .utf8), "first\nsecond\n")
    }

    func testQueryLogEntryJSON() throws {
        var e = QueryLogEntry(queryId: "q-1")
        e.routeIntent = "lookup"
        e.modelId = "gpt-oss:20b"
        e.firstTokenMs = 1200
        e.egressBlockedCount = 0
        let line = try e.jsonLine()
        XCTAssertTrue(line.contains("\"queryId\":\"q-1\""))
        XCTAssertTrue(line.contains("\"modelId\":\"gpt-oss:20b\""))
        XCTAssertFalse(line.contains("document body"))
    }

    func testRedactDocumentText() {
        let long = String(repeating: "x", count: 200)
        let redacted = MnemoLogPaths.redactDocumentText(long)
        XCTAssertLessThan(redacted.count, 200)
        XCTAssertTrue(redacted.hasSuffix("…"))
    }

    func testAllLogFacets() throws {
        var e = QueryLogEntry()
        e.routeIntent = "synthesis"
        e.effortTier = "high"
        e.retrievalHopCount = 3
        e.firstTokenMs = 800
        e.totalMs = 2500
        e.egressBlockedCount = 0
        e.verificationPassRate = 1.0
        e.contextTokenCount = 4000
        e.modelId = "gpt-oss:20b"
        e.terminalState = "answered"
        let line = try e.jsonLine()
        for key in ["routeIntent", "effortTier", "retrievalHopCount", "firstTokenMs",
                    "totalMs", "egressBlockedCount", "verificationPassRate",
                    "contextTokenCount", "modelId", "terminalState"] {
            XCTAssertTrue(line.contains(key), "missing \(key)")
        }
    }

    private func posixPermissions(at url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.posixPermissions] as? NSNumber).intValue
    }
}
