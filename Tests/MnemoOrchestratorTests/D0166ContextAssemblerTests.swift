import XCTest
@testable import MnemoOrchestrator

/// D-0166: ContextAssembler token budget adversarial trim (seed cd2a10499ce2).
final class D0166ContextAssemblerTests: XCTestCase {
    private let seed = "cd2a10499ce2"

    func testAdversarialTrimRespectsBudget() {
        let hits = (0..<20).map { Phase2Fixtures.hit("ContextAssembler", i: $0) }
        let trimmed = ContextAssembler.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertLessThanOrEqual(trimmed.count, hits.count)
        XCTAssertTrue(ContextAssembler.tokenBudgetInvariant(trimmed, budget: 50))
    }
}
