import XCTest
@testable import MnemoOrchestrator

/// D-0054: RouterEscalator answer cache key collision (seed 0ff7d7bdd6cf).
final class D0054RouterEscalatorTests: XCTestCase {
    private let seed = "0ff7d7bdd6cf"

    func testCacheKeyCollisionAvoided() {
        let k1 = RouterEscalator.cacheKey(query: "What is Bazel?", container: "mnemo", extra: "a")
        let k2 = RouterEscalator.cacheKey(query: "what is bazel?", container: "mnemo", extra: "b")
        XCTAssertNotEqual(k1, k2)
    }
}
