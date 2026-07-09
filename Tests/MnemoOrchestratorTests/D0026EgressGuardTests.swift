import XCTest
@testable import MnemoOrchestrator

/// D-0026: EgressGuard token budget adversarial trim (seed 58ec721daad0).
final class D0026EgressGuardTests: XCTestCase {
    private let seed = "58ec721daad0"

    func testAdversarialTrimRespectsBudget() {
        let hits = (0..<20).map { Phase2Fixtures.hit("EgressGuard", i: $0) }
        let trimmed = EgressGuard.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertLessThanOrEqual(trimmed.count, hits.count)
        XCTAssertTrue(EgressGuard.tokenBudgetInvariant(trimmed, budget: 50))
    }
}
