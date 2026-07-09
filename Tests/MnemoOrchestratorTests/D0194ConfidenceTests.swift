import XCTest
@testable import MnemoOrchestrator

/// D-0194: Confidence answer cache key collision (seed fe4778158974).
final class D0194ConfidenceTests: XCTestCase {
    private let seed = "fe4778158974"

    func testCacheKeyCollisionAvoided() {
        let k1 = Confidence.cacheKey(query: "What is Bazel?", container: "mnemo", extra: "a")
        let k2 = Confidence.cacheKey(query: "what is bazel?", container: "mnemo", extra: "b")
        XCTAssertNotEqual(k1, k2)
    }
}
