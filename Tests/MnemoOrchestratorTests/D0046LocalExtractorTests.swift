import XCTest
@testable import MnemoOrchestrator

/// D-0046: LocalExtractor token budget adversarial trim (seed 013d189fc0fa).
final class D0046LocalExtractorTests: XCTestCase {
    private let seed = "013d189fc0fa"

    func testAdversarialTrimRespectsBudget() {
        let hits = (0..<20).map { Phase2Fixtures.hit("LocalExtractor", i: $0) }
        let trimmed = LocalExtractor.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertLessThanOrEqual(trimmed.count, hits.count)
        XCTAssertTrue(LocalExtractor.tokenBudgetInvariant(trimmed, budget: 50))
    }
}
