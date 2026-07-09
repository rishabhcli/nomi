import XCTest
@testable import MnemoOrchestrator

/// D-0546: token budget adversarial trim for NumericReasoner (seed 95da8c91ec27).
final class D0546NumericReasonerTests: XCTestCase {
    private let seed = "95da8c91ec27"

    func testTokenBudget_trimAdversarial() {
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = NumericReasoner.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue(NumericReasoner.tokenBudgetInvariant(trimmed, budget: 50))
    }

    func testTokenBudget_phase2RespectsBudget() {
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }

    func testTokenBudget_emptyHitsInvariant() {
        XCTAssertTrue(NumericReasoner.tokenBudgetInvariant([], budget: 100))
    }
}
