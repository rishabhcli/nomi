import XCTest
@testable import MnemoOrchestrator

/// D-0494: PersonalRanker answer cache key collision (seed 1a4fa51f6598).
final class D0494PersonalRankerTests: XCTestCase {
    private let seed = "1a4fa51f6598"

    func testDistinctVersionsDoNotCollide() async {
        let cache = AnswerCache(ttl: 120)
        await cache.store(query: "what is bazel", container: "mnemo", corpusVersion: 1,
                          answer: "v1", sources: [])
        await cache.store(query: "what is bazel", container: "mnemo", corpusVersion: 2,
                          answer: "v2", sources: [])
        let v1 = await cache.lookup(query: "what is bazel", container: "mnemo", corpusVersion: 1)
        let v2 = await cache.lookup(query: "what is bazel", container: "mnemo", corpusVersion: 2)
        XCTAssertEqual(v1?.answer, "v1")
        XCTAssertEqual(v2?.answer, "v2")
    }

    func testPromptCacheKeyIncludesEvidence() {
        let a = Prompt.answerCacheKey(query: "q", container: "c", corpusVersion: 1, evidence: [Phase2TechniqueSupport.sampleRetrieved()])
        let b = Prompt.answerCacheKey(query: "q", container: "c", corpusVersion: 1,
                                      evidence: [Phase2TechniqueSupport.sampleRetrieved(memory: "Different.")])
        XCTAssertNotEqual(a, b)
    }

    func testProperty_cacheKeyStable() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<5 {
            let q = rng.randomQuery(length: rng.nextInt(upperBound: 4) + 1)
            let k1 = Prompt.answerCacheKey(query: q, container: "mnemo", corpusVersion: 1, evidence: [])
            let k2 = Prompt.answerCacheKey(query: q, container: "mnemo", corpusVersion: 1, evidence: [])
            XCTAssertEqual(k1, k2)
        }
    }
}
