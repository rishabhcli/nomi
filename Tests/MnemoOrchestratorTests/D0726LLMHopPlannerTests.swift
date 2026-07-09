import XCTest
@testable import MnemoOrchestrator

/// D-0726: token budget adversarial trim for LLMHopPlanner (seed 9f9aa6df7cb2).
final class D0726LLMHopPlannerTests: XCTestCase {
    private let seed = "9f9aa6df7cb2"

    func testTokenBudget_trimAdversarial() {
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = LLMHopPlanner.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue(LLMHopPlanner.tokenBudgetInvariant(trimmed, budget: 50))
    }

    func testTokenBudget_phase2RespectsBudget() {
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }

    func testTokenBudget_emptyHitsInvariant() {
        XCTAssertTrue(LLMHopPlanner.tokenBudgetInvariant([], budget: 100))
    }
}
