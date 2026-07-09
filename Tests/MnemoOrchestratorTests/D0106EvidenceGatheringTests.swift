import XCTest
@testable import MnemoOrchestrator

/// D-0106: EvidenceGathering token budget adversarial trim (seed b1b6800e2e1f).
final class D0106EvidenceGatheringTests: XCTestCase {
    private let seed = "b1b6800e2e1f"

    func testAdversarialTrimRespectsBudget() {
        let hits = (0..<20).map { Phase2Fixtures.hit("EvidenceGathering", i: $0) }
        let trimmed = EvidenceGathering.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertLessThanOrEqual(trimmed.count, hits.count)
        XCTAssertTrue(EvidenceGathering.tokenBudgetInvariant(trimmed, budget: 50))
    }
}
