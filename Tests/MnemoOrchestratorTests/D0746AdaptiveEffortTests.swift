import XCTest
@testable import MnemoOrchestrator

/// D-0746: token budget adversarial trim for AdaptiveEffort (seed 4605c0bfceef).
final class D0746AdaptiveEffortTests: XCTestCase {
    private let seed = "4605c0bfceef"

    func testTokenBudget_trimAdversarial() {
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = AdaptiveEffort.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue(AdaptiveEffort.tokenBudgetInvariant(trimmed, budget: 50))
    }

    func testTokenBudget_phase2RespectsBudget() {
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }

    func testTokenBudget_emptyHitsInvariant() {
        XCTAssertTrue(AdaptiveEffort.tokenBudgetInvariant([], budget: 100))
    }
}
