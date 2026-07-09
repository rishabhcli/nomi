import XCTest
@testable import MnemoOrchestrator

/// D-0966: token budget adversarial trim for Preferences (seed 038f0bbfe65c).
final class D0966PreferencesTests: XCTestCase {
    private let seed = "038f0bbfe65c"
    func testTokenBudgetAdversarial_rng() {
        let big = String(repeating: "word ", count: 200)
        let evidence = [Retrieved(memory: big, similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(preamble: "", evidence: evidence, budget: 50))
    }

}
