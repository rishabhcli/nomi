import XCTest
@testable import MnemoOrchestrator

/// D-0186: AnswerCache token budget adversarial trim (seed d3631502ea84).
final class D0186AnswerCacheTests: XCTestCase {
    private let seed = "d3631502ea84"

    func testAdversarialTrimRespectsBudget() {
        let hits = (0..<20).map { Phase2Fixtures.hit("AnswerCache", i: $0) }
        let trimmed = AnswerCache.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertLessThanOrEqual(trimmed.count, hits.count)
        XCTAssertTrue(AnswerCache.tokenBudgetInvariant(trimmed, budget: 50))
    }
}
