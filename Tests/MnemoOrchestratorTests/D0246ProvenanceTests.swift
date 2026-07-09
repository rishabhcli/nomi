import XCTest
@testable import MnemoOrchestrator

/// D-0246: Provenance token budget adversarial trim (seed bba4241ed9f2).
final class D0246ProvenanceTests: XCTestCase {
    private let seed = "bba4241ed9f2"

    func testAdversarialTrimRespectsBudget() {
        let hits = (0..<20).map { Phase2Fixtures.hit("Provenance", i: $0) }
        let trimmed = Provenance.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertLessThanOrEqual(trimmed.count, hits.count)
        XCTAssertTrue(Provenance.tokenBudgetInvariant(trimmed, budget: 50))
    }
}
