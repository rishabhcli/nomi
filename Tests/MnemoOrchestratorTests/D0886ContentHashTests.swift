import XCTest
@testable import MnemoOrchestrator

/// D-0886: token budget adversarial trim for ContentHash (seed 5115849fe641).
final class D0886ContentHashTests: XCTestCase {
    private let seed = "5115849fe641"
    func testTokenBudgetAdversarial_rng() {
        let big = String(repeating: "word ", count: 200)
        let evidence = [Retrieved(memory: big, similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(preamble: "", evidence: evidence, budget: 50))
    }

}
