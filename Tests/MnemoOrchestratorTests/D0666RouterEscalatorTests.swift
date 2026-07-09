import XCTest
@testable import MnemoOrchestrator

/// D-0666: token budget adversarial trim for RouterEscalator (seed 7a56db9d3784).
final class D0666RouterEscalatorTests: XCTestCase {
    private let seed = "7a56db9d3784"

    func testTokenBudget_trimAdversarial() {
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = RouterEscalator.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue(RouterEscalator.tokenBudgetInvariant(trimmed, budget: 50))
    }

    func testTokenBudget_phase2RespectsBudget() {
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }

    func testTokenBudget_emptyHitsInvariant() {
        XCTAssertTrue(RouterEscalator.tokenBudgetInvariant([], budget: 100))
    }
}
