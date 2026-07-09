import XCTest
@testable import MnemoOrchestrator

private func ev(_ text: String, _ sim: Double, path: String = "/f.md") -> Retrieved {
    Retrieved(memory: text, similarity: sim, source: .init(docId: "d", path: path, title: "f"))
}

final class ContextAssemblerTests: XCTestCase {
    let profile = Profile(statics: ["User's name is Alex.", "User is a Rust engineer."],
                          dynamics: ["User is migrating to Bazel."],
                          memories: [])

    func testPreambleContainsStaticAndDynamicFacts() {
        let a = ContextAssembler(tokenBudget: 4000)
        let ctx = a.assemble(intent: .synthesis, question: "q", profile: profile,
                             evidence: [ev("some evidence", 0.8)])
        XCTAssertTrue(ctx.preamble.contains("Alex"))
        XCTAssertTrue(ctx.preamble.contains("Rust engineer"))
        XCTAssertTrue(ctx.preamble.contains("migrating to Bazel"))
    }

    func testTrimsLowestRelevanceEvidenceFirst() {
        // Two equal-cost hits, budget fits only one → the 0.95 must survive.
        let empty = Profile(statics: [], dynamics: [], memories: [])
        let low = ev(String(repeating: "low ", count: 30), 0.30)    // ~30 tokens
        let high = ev("HIGH " + String(repeating: "keep ", count: 29), 0.95)  // ~30 tokens
        let preambleCost = ContextAssembler(tokenBudget: 9999)
            .assemble(intent: .synthesis, question: "q", profile: empty, evidence: []).estimatedTokens
        // Budget = preamble + one hit + a little slack, not two.
        let a = ContextAssembler(tokenBudget: preambleCost + TokenEstimate.of(high.memory) + 2)
        let ctx = a.assemble(intent: .synthesis, question: "q", profile: empty, evidence: [low, high])
        XCTAssertTrue(ctx.evidence.contains { $0.memory.hasPrefix("HIGH ") })
        XCTAssertFalse(ctx.evidence.contains { $0.memory.hasPrefix("low ") })
        XCTAssertLessThanOrEqual(ctx.estimatedTokens, a.tokenBudget)
    }

    func testNeverExceedsBudget() {
        let a = ContextAssembler(tokenBudget: 200)
        let big = (0..<50).map { ev("evidence chunk number \($0) with some words", 0.9 - Double($0) * 0.01) }
        let ctx = a.assemble(intent: .multihop, question: "compare everything",
                             profile: profile, evidence: big)
        XCTAssertLessThanOrEqual(ctx.estimatedTokens, 200)
        XCTAssertGreaterThan(ctx.evidence.count, 0, "keeps as much high-relevance evidence as fits")
    }

    func testPreambleCappedSoEvidenceSurvives() {
        // A huge profile must not crowd out all evidence.
        let hugeProfile = Profile(statics: (0..<200).map { "Static fact number \($0) about the user." },
                                  dynamics: [], memories: [])
        let a = ContextAssembler(tokenBudget: 400)
        let ctx = a.assemble(intent: .synthesis, question: "q", profile: hugeProfile,
                             evidence: [ev("critical evidence that must appear", 0.99)])
        XCTAssertTrue(ctx.evidence.contains { $0.memory.contains("critical evidence") },
                      "preamble is capped; evidence gets the remainder")
        XCTAssertLessThanOrEqual(ctx.estimatedTokens, 400)
    }
}
