import XCTest
@testable import MnemoOrchestrator

/// D-0626: token budget adversarial trim for Prompt (seed d2f9f1b219fc).
final class D0626PromptTests: XCTestCase {
    private let seed = "d2f9f1b219fc"

    func testTokenBudget_trimAdversarial() {
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = Prompt.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue(Prompt.tokenBudgetInvariant(trimmed, budget: 50))
    }

    func testTokenBudget_phase2RespectsBudget() {
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }

    func testTokenBudget_emptyHitsInvariant() {
        XCTAssertTrue(Prompt.tokenBudgetInvariant([], budget: 100))
    }
}
