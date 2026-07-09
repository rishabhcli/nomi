import XCTest
@testable import MnemoOrchestrator

/// D-0514: answer cache key collision for EvidenceGathering (seed 0c46d96f5df9).
final class D0514EvidenceGatheringTests: XCTestCase {
    private let seed = "0c46d96f5df9"

    func testCacheKey_distinctContainers() {
        let k1 = EvidenceGathering.cacheKey(query: "q", container: "work", extra: "")
        let k2 = EvidenceGathering.cacheKey(query: "q", container: "home", extra: "")
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
