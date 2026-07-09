import XCTest
@testable import MnemoOrchestrator

/// D-0014: Prompt answer cache key collision (seed c3b9e894aff0).
final class D0014PromptTests: XCTestCase {
    private let seed = "c3b9e894aff0"

    private func ev(_ mem: String, docId: String) -> Retrieved {
        Retrieved(memory: mem, similarity: 0.8,
                  source: SourceLocator(docId: docId, path: "/\(docId).md", title: docId))
    }

    func testDifferentEvidenceDifferentCacheKey() {
        let q = "what is bazel?"
        let a = Prompt.answerCacheKey(query: q, container: "mnemo", corpusVersion: 1,
                                      evidence: [ev("alpha", docId: "d1")])
        let b = Prompt.answerCacheKey(query: q, container: "mnemo", corpusVersion: 1,
                                      evidence: [ev("beta", docId: "d2")])
        XCTAssertNotEqual(a, b)
    }

    func testSameQueryDifferentContainerDifferentKey() {
        let ev1 = [ev("x", docId: "d1")]
        let k1 = Prompt.answerCacheKey(query: "q", container: "mnemo", corpusVersion: 1, evidence: ev1)
        let k2 = Prompt.answerCacheKey(query: "q", container: "work", corpusVersion: 1, evidence: ev1)
        XCTAssertNotEqual(k1, k2)
    }

    func testContextIncludesDocId() {
        let ctx = Prompt.context([ev("fact text", docId: "doc42")])
        XCTAssertTrue(ctx.contains("id:doc42"))
    }

    func testProperty_cacheKeyStablePerSeed() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let q = rng.randomQuery(length: 3)
            let evidence = [ev("mem \(rng.nextInt(upperBound: 1000))", docId: "d\(rng.nextInt(upperBound: 5))")]
            let k1 = Prompt.answerCacheKey(query: q, container: "c", corpusVersion: 1, evidence: evidence)
            let k2 = Prompt.answerCacheKey(query: q, container: "c", corpusVersion: 1, evidence: evidence)
            XCTAssertEqual(k1, k2)
        }
    }
}
