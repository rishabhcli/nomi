import XCTest
@testable import MnemoOrchestrator

/// D-0554: answer cache key collision for EntityExtractor (seed e73f85971059).
final class D0554EntityExtractorTests: XCTestCase {
    private let seed = "e73f85971059"

    func testCacheKey_distinctContainers() {
        let k1 = EntityExtractor.cacheKey(query: "q", container: "work", extra: "")
        let k2 = EntityExtractor.cacheKey(query: "q", container: "home", extra: "")
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

    func testEntities_extractsMidSentence() {
        let ents = EntityExtractor.entities(in: "Notes mention Rust often.")
        XCTAssertTrue(ents.contains("Rust"))
    }
}
