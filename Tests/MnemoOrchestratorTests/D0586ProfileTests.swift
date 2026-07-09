import XCTest
@testable import MnemoOrchestrator

/// D-0586: token budget adversarial trim for Profile (seed 54d8d8b1aac9).
final class D0586ProfileTests: XCTestCase {
    private let seed = "54d8d8b1aac9"

    func testTokenBudget_trimAdversarial() {
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = Profile.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue(Profile.tokenBudgetInvariant(trimmed, budget: 50))
    }

    func testTokenBudget_phase2RespectsBudget() {
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }

    func testTokenBudget_emptyHitsInvariant() {
        XCTAssertTrue(Profile.tokenBudgetInvariant([], budget: 100))
    }
}
