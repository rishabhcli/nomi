import XCTest
@testable import MnemoOrchestrator

/// D-0212: SpanResolver numeric synthesis distractor immunity (seed 2115c838e98d).
final class D0212SpanResolverTests: XCTestCase {
    private let seed = "2115c838e98d"

    func testRejectsNumericDistractor() {
        XCTAssertTrue(SpanResolver.rejectsNumericDistractor("costs 42 dollars", question: "what is bazel"))
        XCTAssertFalse(SpanResolver.rejectsNumericDistractor("uses bazel", question: "what is bazel"))
    }
}
