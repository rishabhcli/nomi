import XCTest
@testable import MnemoOrchestrator

/// D-0154: QueryService answer cache key collision (seed 2288eb47dd81).
final class D0154QueryServiceTests: XCTestCase {
    private let seed = "2288eb47dd81"

    func testCacheKeyCollisionAvoided() {
        let k1 = QueryService.cacheKey(query: "What is Bazel?", container: "mnemo", extra: "a")
        let k2 = QueryService.cacheKey(query: "what is bazel?", container: "mnemo", extra: "b")
        XCTAssertNotEqual(k1, k2)
    }
}
