import XCTest

/// Platform wiring: mnemoctl registers observability commands (F-phase).
final class MnemoctlPlatformTests: XCTestCase {
    func testMnemoctlObservabilityCommandsRegistered() throws {
        let main = try String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)
        for cmd in ["audit", "egress-check", "stack-report", "logs", "bench", "health"] {
            XCTAssertTrue(main.contains("case \"\(cmd)\""), "missing mnemoctl \(cmd)")
        }
    }

    func testQueryServiceStructuredLogWired() throws {
        let qs = try String(contentsOfFile: "Sources/MnemoOrchestrator/QueryService.swift", encoding: .utf8)
        XCTAssertTrue(qs.contains("logSink: QueryLogSink"))
        XCTAssertTrue(qs.contains("QueryLogTracker"))
        XCTAssertTrue(qs.contains("finishQuery"))
    }
}
