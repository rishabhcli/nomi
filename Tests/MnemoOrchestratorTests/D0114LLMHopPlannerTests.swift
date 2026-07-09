import XCTest
@testable import MnemoOrchestrator

/// D-0114: LLMHopPlanner answer cache key collision (seed 24bcece4843a).
final class D0114LLMHopPlannerTests: XCTestCase {
    private let seed = "24bcece4843a"

    func testCacheKeyCollisionAvoided() {
        let k1 = LLMHopPlanner.cacheKey(query: "What is Bazel?", container: "mnemo", extra: "a")
        let k2 = LLMHopPlanner.cacheKey(query: "what is bazel?", container: "mnemo", extra: "b")
        XCTAssertNotEqual(k1, k2)
    }
}
