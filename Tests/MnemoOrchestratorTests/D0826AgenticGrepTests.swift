import XCTest
@testable import MnemoOrchestrator

/// D-0826: token budget adversarial trim for AgenticGrep (seed ee0c266974be).
final class D0826AgenticGrepTests: XCTestCase {
    private let seed = "ee0c266974be"
    func testTokenBudgetAdversarial_rng() {
        let big = String(repeating: "word ", count: 200)
        let evidence = [Retrieved(memory: big, similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(preamble: "", evidence: evidence, budget: 50))
    }

}
