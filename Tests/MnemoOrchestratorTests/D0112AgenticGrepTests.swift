import XCTest
@testable import MnemoOrchestrator

/// D-0112: AgenticGrep numeric synthesis distractor immunity (seed 060cf86823bd).
final class D0112AgenticGrepTests: XCTestCase {
    private let seed = "060cf86823bd"

    func testRejectsNumericDistractor() {
        XCTAssertTrue(AgenticGrep.rejectsNumericDistractor("costs 42 dollars", question: "what is bazel"))
        XCTAssertFalse(AgenticGrep.rejectsNumericDistractor("uses bazel", question: "what is bazel"))
    }
}
