import XCTest
@testable import MnemoOrchestrator

/// D-0686: token budget adversarial trim for LLMSynthesizer (seed 7ac25dd9cca1).
final class D0686LLMSynthesizerTests: XCTestCase {
    private let seed = "7ac25dd9cca1"

    func testTokenBudget_trimAdversarial() {
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = LLMSynthesizer.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue(LLMSynthesizer.tokenBudgetInvariant(trimmed, budget: 50))
    }

    func testTokenBudget_phase2RespectsBudget() {
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }

    func testTokenBudget_emptyHitsInvariant() {
        XCTAssertTrue(LLMSynthesizer.tokenBudgetInvariant([], budget: 100))
    }
}
