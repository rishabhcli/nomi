import XCTest
@testable import MnemoOrchestrator

/// D-0072: ConflictDetector numeric synthesis distractor immunity (seed d49ba2190609).
final class D0072ConflictDetectorTests: XCTestCase {
    private let seed = "d49ba2190609"

    func testRejectsNumericDistractor() {
        XCTAssertTrue(ConflictDetector.rejectsNumericDistractor("costs 42 dollars", question: "what is bazel"))
        XCTAssertFalse(ConflictDetector.rejectsNumericDistractor("uses bazel", question: "what is bazel"))
    }
}
