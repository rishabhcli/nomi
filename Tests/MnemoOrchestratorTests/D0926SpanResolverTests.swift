import XCTest
@testable import MnemoOrchestrator

/// D-0926: token budget adversarial trim for SpanResolver (seed e9bb75436888).
final class D0926SpanResolverTests: XCTestCase {
    private let seed = "e9bb75436888"
    func testTokenBudgetAdversarial_rng() {
        let big = String(repeating: "word ", count: 200)
        let evidence = [Retrieved(memory: big, similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(preamble: "", evidence: evidence, budget: 50))
    }

}
