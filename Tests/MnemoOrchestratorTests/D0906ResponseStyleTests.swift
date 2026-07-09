import XCTest
@testable import MnemoOrchestrator

/// D-0906: token budget adversarial trim for ResponseStyle (seed 2d3468271300).
final class D0906ResponseStyleTests: XCTestCase {
    private let seed = "2d3468271300"
    func testTokenBudgetAdversarial_rng() {
        let big = String(repeating: "word ", count: 200)
        let evidence = [Retrieved(memory: big, similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(preamble: "", evidence: evidence, budget: 50))
    }

}
