import XCTest
@testable import MnemoOrchestrator

/// D-0092: Confidence numeric synthesis distractor immunity (seed 2d57d86bd5c5).
final class D0092ConfidenceTests: XCTestCase {
    private let seed = "2d57d86bd5c5"

    func testRejectsNumericDistractor() {
        XCTAssertTrue(Confidence.rejectsNumericDistractor("costs 42 dollars", question: "what is bazel"))
        XCTAssertFalse(Confidence.rejectsNumericDistractor("uses bazel", question: "what is bazel"))
    }
}
