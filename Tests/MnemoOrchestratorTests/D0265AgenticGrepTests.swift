import XCTest
@testable import MnemoOrchestrator

/// D-0265: AgenticGrep cache poisoning resistance (seed 51bf2d9459e7).
final class D0265AgenticGrepTests: XCTestCase {
    private let seed = "51bf2d9459e7"

    func testVersionMismatchEvicts() async {
        let cache = AnswerCache(ttl: 120)
        await cache.store(query: "q", container: "c", corpusVersion: 1, answer: "old", sources: [])
        let miss = await cache.lookup(query: "q", container: "c", corpusVersion: 99)
        XCTAssertNil(miss)
    }

    func testTTLExpiry() async {
        let cache = AnswerCache(ttl: 1)
        let past = Date().timeIntervalSinceReferenceDate - 10
        await cache.store(query: "q", container: "c", corpusVersion: 1, answer: "x", sources: [], at: past)
        XCTAssertNil(await cache.lookup(query: "q", container: "c", corpusVersion: 1))
    }

    func testProperty_distinctEvidenceDistinctKey() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<5 {
            let q = rng.randomQuery(length: 2)
            let e1 = [Phase2TechniqueSupport.sampleRetrieved(memory: "a\(rng.nextInt(upperBound: 100))")]
            let e2 = [Phase2TechniqueSupport.sampleRetrieved(memory: "b\(rng.nextInt(upperBound: 100))")]
            let k1 = Prompt.answerCacheKey(query: q, container: "c", corpusVersion: 1, evidence: e1)
            let k2 = Prompt.answerCacheKey(query: q, container: "c", corpusVersion: 1, evidence: e2)
            if e1[0].memory != e2[0].memory { XCTAssertNotEqual(k1, k2) }
        }
    }
}
