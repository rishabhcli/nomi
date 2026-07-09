import XCTest
@testable import MnemoOrchestrator

/// D-0766: token budget adversarial trim for QueryService (seed b6cb510951b3).
final class D0766QueryServiceTests: XCTestCase {
    private let seed = "b6cb510951b3"
    func testTokenBudgetAdversarial_rng() {
        let big = String(repeating: "word ", count: 200)
        let evidence = [Retrieved(memory: big, similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(preamble: "", evidence: evidence, budget: 50))
    }

}
