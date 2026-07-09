import XCTest
@testable import MnemoOrchestrator

/// D-0446: TimelineBuilder token budget adversarial trim (seed 223b45b34635).
final class D0446TimelineBuilderTests: XCTestCase {
    private let seed = "223b45b34635"

    func testContextAssemblerTrimsOversized() {
        let big = Retrieved(memory: String(repeating: "word ", count: 500), similarity: 0.9,
                            source: .init(docId: "b", path: "/b.md", title: "b"))
        let small = Phase2TechniqueSupport.sampleRetrieved(memory: "tiny")
        let asm = ContextAssembler(tokenBudget: 50)
        let ctx = asm.assemble(intent: .lookup, question: "q", profile: Phase2TechniqueSupport.sampleProfile(),
                               evidence: [big, small])
        XCTAssertFalse(ctx.evidence.isEmpty)
        XCTAssertLessThanOrEqual(ctx.estimatedTokens, 50)
    }

    func testTokenEstimateNonZero() {
        XCTAssertGreaterThanOrEqual(TokenEstimate.of(""), 1)
    }

    func testProperty_budgetNeverNegative() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<5 {
            let budget = 20 + rng.nextInt(upperBound: 80)
            let asm = ContextAssembler(tokenBudget: budget)
            let ctx = asm.assemble(intent: .lookup, question: "q", profile: Profile(statics: [], dynamics: [], memories: []),
                                   evidence: [Phase2TechniqueSupport.sampleRetrieved()])
            XCTAssertLessThanOrEqual(ctx.estimatedTokens, budget)
        }
    }
}
