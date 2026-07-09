import XCTest
@testable import MnemoOrchestrator

/// D-0986: token budget adversarial trim for IngestGate (seed d4df7fb34801).
final class D0986IngestGateTests: XCTestCase {
    private let seed = "d4df7fb34801"
    func testTokenBudgetAdversarial_rng() {
        let big = String(repeating: "word ", count: 200)
        let evidence = [Retrieved(memory: big, similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(preamble: "", evidence: evidence, budget: 50))
    }

}
