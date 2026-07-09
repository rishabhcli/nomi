import XCTest
@testable import MnemoOrchestrator

/// D-0786: token budget adversarial trim for ConflictDetector (seed 65db931a6e32).
final class D0786ConflictDetectorTests: XCTestCase {
    private let seed = "65db931a6e32"
    func testTokenBudgetAdversarial_rng() {
        let big = String(repeating: "word ", count: 200)
        let evidence = [Retrieved(memory: big, similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(preamble: "", evidence: evidence, budget: 50))
    }

}
