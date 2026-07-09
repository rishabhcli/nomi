import XCTest
@testable import MnemoOrchestrator

/// D-0234: QueryDecomposer answer cache key collision (seed bcb99b19a4df).
final class D0234QueryDecomposerTests: XCTestCase {
    private let seed = "bcb99b19a4df"

    func testCacheKeyCollisionAvoided() {
        let k1 = QueryDecomposer.cacheKey(query: "What is Bazel?", container: "mnemo", extra: "a")
        let k2 = QueryDecomposer.cacheKey(query: "what is bazel?", container: "mnemo", extra: "b")
        XCTAssertNotEqual(k1, k2)
    }
}
