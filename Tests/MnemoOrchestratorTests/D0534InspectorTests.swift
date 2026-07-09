import XCTest
@testable import MnemoOrchestrator

/// D-0534: answer cache key collision for Inspector (seed 6acd916dacec).
final class D0534InspectorTests: XCTestCase {
    private let seed = "6acd916dacec"

    func testCacheKey_distinctContainers() {
        let k1 = Inspector.cacheKey(query: "q", container: "work", extra: "")
        let k2 = Inspector.cacheKey(query: "q", container: "home", extra: "")
        XCTAssertNotEqual(k1, k2)
    }

    func testCacheKey_phase2Distinct() {
        XCTAssertTrue(Phase2Techniques.cacheKeysDistinct([("a", "c1"), ("b", "c1")]))
    }

    func testCacheKey_caseNormalized() async {
        let cache = AnswerCache(ttl: 60)
        await cache.store(query: "Q", container: "c", corpusVersion: 1, answer: "x", sources: [])
        let hit = await cache.lookup(query: "q", container: "c", corpusVersion: 1)
        XCTAssertEqual(hit?.answer, "x")
    }
}
