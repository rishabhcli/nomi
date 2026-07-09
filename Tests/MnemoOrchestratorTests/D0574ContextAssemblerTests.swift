import XCTest
@testable import MnemoOrchestrator

/// D-0574: answer cache key collision for ContextAssembler (seed c109e876a20b).
final class D0574ContextAssemblerTests: XCTestCase {
    private let seed = "c109e876a20b"

    func testCacheKey_distinctContainers() {
        let k1 = ContextAssembler.cacheKey(query: "q", container: "work", extra: "")
        let k2 = ContextAssembler.cacheKey(query: "q", container: "home", extra: "")
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
