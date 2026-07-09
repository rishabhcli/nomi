import XCTest
@testable import MnemoOrchestrator

/// D-0146: EntityExtractor token budget adversarial trim (seed f7cdf76ea677).
final class D0146EntityExtractorTests: XCTestCase {
    private let seed = "f7cdf76ea677"

    func testAdversarialTrimRespectsBudget() {
        let hits = (0..<20).map { Phase2Fixtures.hit("EntityExtractor", i: $0) }
        let trimmed = EntityExtractor.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertLessThanOrEqual(trimmed.count, hits.count)
        XCTAssertTrue(EntityExtractor.tokenBudgetInvariant(trimmed, budget: 50))
    }
}
