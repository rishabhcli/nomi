import XCTest
@testable import MnemoOrchestrator

/// D-0606: token budget adversarial trim for MediaCompanion (seed 3a301d7a1744).
final class D0606MediaCompanionTests: XCTestCase {
    private let seed = "3a301d7a1744"

    func testTokenBudget_trimAdversarial() {
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = MediaCompanion.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue(MediaCompanion.tokenBudgetInvariant(trimmed, budget: 50))
    }

    func testTokenBudget_phase2RespectsBudget() {
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }

    func testTokenBudget_emptyHitsInvariant() {
        XCTAssertTrue(MediaCompanion.tokenBudgetInvariant([], budget: 100))
    }
}
