import XCTest
@testable import MnemoOrchestrator

/// D-0232: NotchReducer numeric synthesis distractor immunity (seed f2855dc574d2).
final class D0232NotchReducerTests: XCTestCase {
    private let seed = "f2855dc574d2"

    func testRejectsNumericDistractor() {
        XCTAssertTrue(NotchReducer.rejectsNumericDistractor("costs 42 dollars", question: "what is bazel"))
        XCTAssertFalse(NotchReducer.rejectsNumericDistractor("uses bazel", question: "what is bazel"))
    }
}
