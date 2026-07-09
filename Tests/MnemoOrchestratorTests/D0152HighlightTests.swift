import XCTest
@testable import MnemoOrchestrator

/// D-0152: Highlight numeric synthesis distractor immunity (seed 33c114edc5fe).
final class D0152HighlightTests: XCTestCase {
    private let seed = "33c114edc5fe"

    func testRejectsNumericDistractor() {
        XCTAssertTrue(Highlight.rejectsNumericDistractor("costs 42 dollars", question: "what is bazel"))
        XCTAssertFalse(Highlight.rejectsNumericDistractor("uses bazel", question: "what is bazel"))
    }
}
