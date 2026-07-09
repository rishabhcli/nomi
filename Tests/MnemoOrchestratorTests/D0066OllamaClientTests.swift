import XCTest
@testable import MnemoOrchestrator

/// D-0066: OllamaClient token budget adversarial trim (seed fedb1e0269de).
final class D0066OllamaClientTests: XCTestCase {
    private let seed = "fedb1e0269de"

    func testAdversarialTrimRespectsBudget() {
        let hits = (0..<20).map { Phase2Fixtures.hit("OllamaClient", i: $0) }
        let trimmed = OllamaClient.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertLessThanOrEqual(trimmed.count, hits.count)
        XCTAssertTrue(OllamaClient.tokenBudgetInvariant(trimmed, budget: 50))
    }
}
