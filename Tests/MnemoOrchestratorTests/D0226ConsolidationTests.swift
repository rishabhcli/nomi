import XCTest
@testable import MnemoOrchestrator

/// D-0226: Consolidation token budget adversarial trim (seed ca76ed52a7cf).
final class D0226ConsolidationTests: XCTestCase {
    private let seed = "ca76ed52a7cf"

    func testAdversarialTrimRespectsBudget() {
        let hits = (0..<20).map { Phase2Fixtures.hit("Consolidation", i: $0) }
        let trimmed = Consolidation.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertLessThanOrEqual(trimmed.count, hits.count)
        XCTAssertTrue(Consolidation.tokenBudgetInvariant(trimmed, budget: 50))
    }
}
