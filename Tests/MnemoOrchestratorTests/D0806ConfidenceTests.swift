import XCTest
@testable import MnemoOrchestrator

/// D-0806: token budget adversarial trim for Confidence (seed a8349b2cb3e1).
final class D0806ConfidenceTests: XCTestCase {
    private let seed = "a8349b2cb3e1"
    func testTokenBudgetAdversarial_rng() {
        let big = String(repeating: "word ", count: 200)
        let evidence = [Retrieved(memory: big, similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(preamble: "", evidence: evidence, budget: 50))
    }

}
