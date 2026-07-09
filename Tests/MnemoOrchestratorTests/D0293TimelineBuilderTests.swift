import XCTest
@testable import MnemoOrchestrator

/// D-0293: TimelineBuilder profile preamble staleness (seed 04d44d6c2cf1).
final class D0293TimelineBuilderTests: XCTestCase {
    private let seed = "04d44d6c2cf1"

    func testStaleFactsDetected() {
        let profile = Phase2TechniqueSupport.sampleProfile()
        let active: Set<String> = ["Works on Mnemo."]
        let stale = ContextAssembler.staleFacts(in: profile, activeTexts: active)
        XCTAssertTrue(stale.contains("Asked about Bazel."))
    }

    func testNormalizedStaleMatch() {
        let profile = Profile(statics: ["Works on Mnemo!"], dynamics: [], memories: [])
        let stale = ContextAssembler.staleFacts(in: profile, activeTexts: ["works on mnemo"])
        XCTAssertTrue(stale.isEmpty)
    }

    func testProperty_preambleCapRespected() {
        var rng = Phase2RNG(seed: seed)
        let asm = ContextAssembler(tokenBudget: 200, preambleFraction: 0.5)
        for i in 0..<4 {
            let facts = (0..<rng.nextInt(upperBound: 5) + 1).map { "fact \(i)-\($0) " + rng.randomQuery(length: 1) }
            let p = Profile(statics: facts, dynamics: [], memories: [])
            let ctx = asm.assemble(intent: .lookup, question: "q", profile: p, evidence: [])
            XCTAssertLessThanOrEqual(ctx.estimatedTokens, 200)
        }
    }
}
