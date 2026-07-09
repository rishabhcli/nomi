import XCTest
@testable import MnemoOrchestrator

/// D-0034: QueryHistory answer cache key collision (seed ef89506199ed).
final class D0034QueryHistoryTests: XCTestCase {
    private let seed = "ef89506199ed"

    func testCacheKeyCollisionAvoided() {
        let k1 = QueryHistory.cacheKey(query: "What is Bazel?", container: "mnemo", extra: "a")
        let k2 = QueryHistory.cacheKey(query: "what is bazel?", container: "mnemo", extra: "b")
        XCTAssertNotEqual(k1, k2)
    }
}
