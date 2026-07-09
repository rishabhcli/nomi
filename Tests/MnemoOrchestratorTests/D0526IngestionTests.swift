import XCTest
@testable import MnemoOrchestrator

/// D-0526: token budget adversarial trim for Ingestion (seed 213d6ba642f3).
final class D0526IngestionTests: XCTestCase {
    private let seed = "213d6ba642f3"

    func testTokenBudget_trimAdversarial() {
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = Ingestion.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue(Ingestion.tokenBudgetInvariant(trimmed, budget: 50))
    }

    func testTokenBudget_phase2RespectsBudget() {
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }

    func testTokenBudget_emptyHitsInvariant() {
        XCTAssertTrue(Ingestion.tokenBudgetInvariant([], budget: 100))
    }
}
