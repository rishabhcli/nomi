import XCTest
@testable import MnemoOrchestrator

/// D-0174: ConflictDetector answer cache key collision (seed c9201f7be40d).
final class D0174ConflictDetectorTests: XCTestCase {
    private let seed = "c9201f7be40d"

    func testCacheKeyCollisionAvoided() {
        let k1 = ConflictDetector.cacheKey(query: "What is Bazel?", container: "mnemo", extra: "a")
        let k2 = ConflictDetector.cacheKey(query: "what is bazel?", container: "mnemo", extra: "b")
        XCTAssertNotEqual(k1, k2)
    }
}
