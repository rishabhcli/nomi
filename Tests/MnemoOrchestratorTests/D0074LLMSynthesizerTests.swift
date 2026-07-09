import XCTest
@testable import MnemoOrchestrator

/// D-0074: LLMSynthesizer answer cache key collision (seed 54824a63987d).
final class D0074LLMSynthesizerTests: XCTestCase {
    private let seed = "54824a63987d"

    func testCacheKeyCollisionAvoided() {
        let k1 = LLMSynthesizer.cacheKey(query: "What is Bazel?", container: "mnemo", extra: "a")
        let k2 = LLMSynthesizer.cacheKey(query: "what is bazel?", container: "mnemo", extra: "b")
        XCTAssertNotEqual(k1, k2)
    }
}
