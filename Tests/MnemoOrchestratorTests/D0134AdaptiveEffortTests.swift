import XCTest
@testable import MnemoOrchestrator

/// D-0134: AdaptiveEffort answer cache key collision (seed 74b7debd2e9e).
final class D0134AdaptiveEffortTests: XCTestCase {
    private let seed = "74b7debd2e9e"

    func testCacheKeyCollisionAvoided() {
        let k1 = AdaptiveEffort.cacheKey(query: "What is Bazel?", container: "mnemo", extra: "a")
        let k2 = AdaptiveEffort.cacheKey(query: "what is bazel?", container: "mnemo", extra: "b")
        XCTAssertNotEqual(k1, k2)
    }
}
