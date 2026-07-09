import XCTest
@testable import MnemoOrchestrator

/// D-0132: QueryDecomposer numeric synthesis distractor immunity (seed 3baa5fe0b6cd).
final class D0132QueryDecomposerTests: XCTestCase {
    private let seed = "3baa5fe0b6cd"

    func testRejectsNumericDistractor() {
        XCTAssertTrue(QueryDecomposer.rejectsNumericDistractor("costs 42 dollars", question: "what is bazel"))
        XCTAssertFalse(QueryDecomposer.rejectsNumericDistractor("uses bazel", question: "what is bazel"))
    }
}
