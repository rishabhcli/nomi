import XCTest
@testable import MnemoOrchestrator

/// D-0734: answer cache key collision for MemoryDynamics (seed 7898a23c0bcb).
final class D0734MemoryDynamicsTests: XCTestCase {
    private let seed = "7898a23c0bcb"

    func testCacheKey_distinctContainers() {
        let k1 = MemoryDynamics.cacheKey(query: "q", container: "work", extra: "")
        let k2 = MemoryDynamics.cacheKey(query: "q", container: "home", extra: "")
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
