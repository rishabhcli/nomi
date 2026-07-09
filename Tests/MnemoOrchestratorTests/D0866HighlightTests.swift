import XCTest
@testable import MnemoOrchestrator

/// D-0866: token budget adversarial trim for Highlight (seed 10540c8c156d).
final class D0866HighlightTests: XCTestCase {
    private let seed = "10540c8c156d"
    func testTokenBudgetAdversarial_rng() {
        let big = String(repeating: "word ", count: 200)
        let evidence = [Retrieved(memory: big, similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(preamble: "", evidence: evidence, budget: 50))
    }

}
