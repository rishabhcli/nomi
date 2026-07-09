import XCTest
@testable import MnemoOrchestrator

/// D-0094: CommandParser answer cache key collision (seed c95ad5c6f0f8).
final class D0094CommandParserTests: XCTestCase {
    private let seed = "c95ad5c6f0f8"

    func testCacheKeyCollisionAvoided() {
        let k1 = CommandParser.cacheKey(query: "What is Bazel?", container: "mnemo", extra: "a")
        let k2 = CommandParser.cacheKey(query: "what is bazel?", container: "mnemo", extra: "b")
        XCTAssertNotEqual(k1, k2)
    }
}
