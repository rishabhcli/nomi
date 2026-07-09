import XCTest
@testable import MnemoOrchestrator

/// D-0052: QueryService numeric synthesis distractor immunity (seed 876f36438d31).
final class D0052QueryServiceTests: XCTestCase {
    private let seed = "876f36438d31"

    func testRejectsNumericDistractor() {
        XCTAssertTrue(QueryService.rejectsNumericDistractor("costs 42 dollars", question: "what is bazel"))
        XCTAssertFalse(QueryService.rejectsNumericDistractor("uses bazel", question: "what is bazel"))
    }
}
