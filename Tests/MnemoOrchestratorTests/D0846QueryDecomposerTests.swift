import XCTest
@testable import MnemoOrchestrator

/// D-0846: token budget adversarial trim for QueryDecomposer (seed 1dbce55f9e21).
final class D0846QueryDecomposerTests: XCTestCase {
    private let seed = "1dbce55f9e21"
    func testTokenBudgetAdversarial_rng() {
        let big = String(repeating: "word ", count: 200)
        let evidence = [Retrieved(memory: big, similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(preamble: "", evidence: evidence, budget: 50))
    }

}
