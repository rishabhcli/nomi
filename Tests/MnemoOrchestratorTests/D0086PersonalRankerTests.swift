import XCTest
@testable import MnemoOrchestrator

/// D-0086: PersonalRanker token budget adversarial trim (seed 844a74140ff6).
final class D0086PersonalRankerTests: XCTestCase {
    private let seed = "844a74140ff6"

    func testAdversarialTrimRespectsBudget() {
        let hits = (0..<20).map { Phase2Fixtures.hit("PersonalRanker", i: $0) }
        let trimmed = PersonalRanker.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertLessThanOrEqual(trimmed.count, hits.count)
        XCTAssertTrue(PersonalRanker.tokenBudgetInvariant(trimmed, budget: 50))
    }
}
