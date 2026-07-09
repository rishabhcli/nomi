import XCTest
@testable import MnemoOrchestrator

/// D-0126: Inspector token budget adversarial trim (seed 8c17dbd84f70).
final class D0126InspectorTests: XCTestCase {
    private let seed = "8c17dbd84f70"

    func testAdversarialTrimRespectsBudget() {
        let hits = (0..<20).map { Phase2Fixtures.hit("Inspector", i: $0) }
        let trimmed = Inspector.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertLessThanOrEqual(trimmed.count, hits.count)
        XCTAssertTrue(Inspector.tokenBudgetInvariant(trimmed, budget: 50))
    }
}
