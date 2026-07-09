import XCTest
@testable import MnemoOrchestrator

/// D-0032: AdaptiveEffort numeric synthesis distractor immunity (seed 6cc79c3a181b).
final class D0032AdaptiveEffortTests: XCTestCase {
    private let seed = "6cc79c3a181b"

    func testRejectsNumericDistractor() {
        XCTAssertTrue(AdaptiveEffort.rejectsNumericDistractor("costs 42 dollars", question: "what is bazel"))
        XCTAssertFalse(AdaptiveEffort.rejectsNumericDistractor("uses bazel", question: "what is bazel"))
    }
}
