import XCTest
@testable import MnemoOrchestrator

/// M1: the always-on trust footer content model — "● 0 outbound · 0.4s · Grounded".
/// Egress is per-query and honest; confidence is only claimed once there's an answer.
final class M1TrustFooterTests: XCTestCase {
    func testEgressCleanWhenZeroDelta() {
        let f = TrustFooterModel.make(metrics: QueryMetrics(totalMs: 420, egressBlockedCount: 0),
                                      confidence: .high, hasAnswer: true)
        XCTAssertTrue(f.egressClean)
        XCTAssertEqual(f.egressText, "0 outbound")
    }

    func testEgressWarnsWhenBlocked() {
        let f = TrustFooterModel.make(metrics: QueryMetrics(egressBlockedCount: 3),
                                      confidence: .low, hasAnswer: true)
        XCTAssertFalse(f.egressClean)
        XCTAssertEqual(f.egressText, "3 blocked")
    }

    func testTimeFormatsMsAndSeconds() {
        XCTAssertEqual(TrustFooterModel.make(metrics: QueryMetrics(totalMs: 420),
                                             confidence: .high, hasAnswer: true).timeText, "420ms")
        XCTAssertEqual(TrustFooterModel.make(metrics: QueryMetrics(totalMs: 1500),
                                             confidence: .high, hasAnswer: true).timeText, "1.5s")
    }

    func testConfidenceOnlyClaimedWithAnswer() {
        XCTAssertNil(TrustFooterModel.make(metrics: nil, confidence: .high, hasAnswer: false).confidence)
        XCTAssertEqual(TrustFooterModel.make(metrics: nil, confidence: .high, hasAnswer: true).confidenceLabel, "Grounded")
        XCTAssertEqual(TrustFooterModel.make(metrics: nil, confidence: .medium, hasAnswer: true).confidenceLabel, "Check citations")
        XCTAssertEqual(TrustFooterModel.make(metrics: nil, confidence: .low, hasAnswer: true).confidenceLabel, "Low confidence")
    }

    func testStaysCleanBeforeMetricsArrive() {
        let f = TrustFooterModel.make(metrics: nil, confidence: .medium, hasAnswer: false)
        XCTAssertTrue(f.egressClean)                 // loopback-only: 0 is the truthful default
        XCTAssertEqual(f.egressText, "0 outbound")
        XCTAssertNil(f.timeText)                      // no timing until the query finishes
    }
}
