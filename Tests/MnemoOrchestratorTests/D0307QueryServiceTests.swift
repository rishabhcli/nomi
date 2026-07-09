import XCTest
@testable import MnemoOrchestrator

/// D-0307: QueryService router escalation boundaries (seed 0720803f7d9c).
final class D0307QueryServiceTests: XCTestCase {
    private let seed = "0720803f7d9c"

    func testCoverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "semantic", rerank: true, threshold: 0.8, limit: 5, container: "c")
        let esc = Coverage.escalate(base)
        XCTAssertGreaterThanOrEqual(esc.threshold, 0.1)
        XCTAssertEqual(esc.limit, base.limit * 2)
    }

    func testWeakTriggersEscalation() {
        XCTAssertTrue(Coverage.isWeak(topSimilarity: 0.2, count: 3))
    }

    func testProperty_escalateThresholdMonotonic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<5 {
            let t = Double(rng.nextInt(upperBound: 80) + 10) / 100.0
            let base = SearchRequest(q: "q", searchMode: "semantic", rerank: false, threshold: t, limit: 4, container: "c")
            let esc = Coverage.escalate(base)
            XCTAssertLessThanOrEqual(esc.threshold, t)
        }
    }
}
