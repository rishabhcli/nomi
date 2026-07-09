import XCTest
@testable import MnemoOrchestrator

/// D-0214: AgenticGrep answer cache key collision (seed 7a04c3802256).
final class D0214AgenticGrepTests: XCTestCase {
    private let seed = "7a04c3802256"

    func testCacheKeyCollisionAvoided() {
        let k1 = AgenticGrep.cacheKey(query: "What is Bazel?", container: "mnemo", extra: "a")
        let k2 = AgenticGrep.cacheKey(query: "what is bazel?", container: "mnemo", extra: "b")
        XCTAssertNotEqual(k1, k2)
    }
}
