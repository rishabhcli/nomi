import XCTest
@testable import MnemoOrchestrator

/// D-0506: token budget adversarial trim for Digest (seed 2c493ffa05f0).
final class D0506DigestTests: XCTestCase {
    private let seed = "2c493ffa05f0"

    func testTokenBudget_trimAdversarial() {
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = Digest.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue(Digest.tokenBudgetInvariant(trimmed, budget: 50))
    }

    func testTokenBudget_phase2RespectsBudget() {
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }

    func testTokenBudget_emptyHitsInvariant() {
        XCTAssertTrue(Digest.tokenBudgetInvariant([], budget: 100))
    }
}
