import XCTest
@testable import MnemoOrchestrator

/// D-0646: token budget adversarial trim for QueryHistory (seed b17caead803f).
final class D0646QueryHistoryTests: XCTestCase {
    private let seed = "b17caead803f"

    func testTokenBudget_trimAdversarial() {
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = QueryHistory.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue(QueryHistory.tokenBudgetInvariant(trimmed, budget: 50))
    }

    func testTokenBudget_phase2RespectsBudget() {
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }

    func testTokenBudget_emptyHitsInvariant() {
        XCTAssertTrue(QueryHistory.tokenBudgetInvariant([], budget: 100))
    }
}
