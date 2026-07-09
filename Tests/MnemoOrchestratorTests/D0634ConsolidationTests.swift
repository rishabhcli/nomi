import XCTest
@testable import MnemoOrchestrator

/// D-0634: answer cache key collision for Consolidation (seed cdc2587d3d49).
final class D0634ConsolidationTests: XCTestCase {
    private let seed = "cdc2587d3d49"

    func testCacheKey_distinctContainers() {
        let k1 = Consolidation.cacheKey(query: "q", container: "work", extra: "")
        let k2 = Consolidation.cacheKey(query: "q", container: "home", extra: "")
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
