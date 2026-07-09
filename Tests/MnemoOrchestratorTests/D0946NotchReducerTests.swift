import XCTest
@testable import MnemoOrchestrator

/// D-0946: token budget adversarial trim for NotchReducer (seed e767dddaf445).
final class D0946NotchReducerTests: XCTestCase {
    private let seed = "e767dddaf445"
    func testTokenBudgetAdversarial_rng() {
        let big = String(repeating: "word ", count: 200)
        let evidence = [Retrieved(memory: big, similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(preamble: "", evidence: evidence, budget: 50))
    }

}
