import XCTest
@testable import MnemoOrchestrator

/// D-0013: ContextAssembler profile preamble staleness (seed bdafd1517fcd).
final class D0013ContextAssemblerTests: XCTestCase {
    private let seed = "bdafd1517fcd"

    let profile = Profile(statics: ["User name is Alex.", "User likes Rust."],
                          dynamics: ["User moved to SF."], memories: [])

    func testStaleFactsDetected() {
        let stale = ContextAssembler.staleFacts(in: profile, activeTexts: ["User name is Alex."])
        XCTAssertEqual(stale, ["User likes Rust.", "User moved to SF."])
    }

    func testActiveFactFilterRemovesStaleFromPreamble() {
        let asm = ContextAssembler(tokenBudget: 4000)
        let ctx = asm.assemble(intent: .profile, question: "who am I?", profile: profile,
                               evidence: [], activeFactTexts: ["User name is Alex."])
        XCTAssertTrue(ctx.preamble.contains("Alex"))
        XCTAssertFalse(ctx.preamble.contains("Rust"))
        XCTAssertFalse(ctx.preamble.contains("SF"))
    }

    func testPreambleStampPresent() {
        let asm = ContextAssembler(tokenBudget: 500)
        let ctx = asm.assemble(intent: .lookup, question: "q", profile: profile, evidence: [])
        XCTAssertTrue(ctx.preamble.contains("profile-stamp:"))
    }

    func testProperty_assemblyRespectsBudgetWithStaleFilter() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<6 {
            let budget = 100 + rng.nextInt(upperBound: 200)
            let asm = ContextAssembler(tokenBudget: budget)
            let active = Set(profile.statics.prefix(1))
            let ctx = asm.assemble(intent: .synthesis, question: "q", profile: profile,
                                   evidence: [], activeFactTexts: active)
            XCTAssertLessThanOrEqual(ctx.estimatedTokens, budget)
        }
    }
}
