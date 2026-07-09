import XCTest
@testable import MnemoOrchestrator

/// D-0206: Router token budget adversarial trim (seed b35ee468fa3d).
final class D0206RouterTests: XCTestCase {
    private let seed = "b35ee468fa3d"

    func testAdversarialTrimRespectsBudget() {
        let hits = (0..<20).map { Phase2Fixtures.hit("Router", i: $0) }
        let trimmed = Router.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertLessThanOrEqual(trimmed.count, hits.count)
        XCTAssertTrue(Router.tokenBudgetInvariant(trimmed, budget: 50))
    }
}
