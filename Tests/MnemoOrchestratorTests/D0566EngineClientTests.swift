import XCTest
@testable import MnemoOrchestrator

/// D-0566: token budget adversarial trim for EngineClient (seed d8a7faadceae).
final class D0566EngineClientTests: XCTestCase {
    private let seed = "d8a7faadceae"

    func testTokenBudget_trimAdversarial() {
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = EngineClient.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue(EngineClient.tokenBudgetInvariant(trimmed, budget: 50))
    }

    func testTokenBudget_phase2RespectsBudget() {
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }

    func testTokenBudget_emptyHitsInvariant() {
        XCTAssertTrue(EngineClient.tokenBudgetInvariant([], budget: 100))
    }
}
