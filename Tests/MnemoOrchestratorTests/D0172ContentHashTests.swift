import XCTest
@testable import MnemoOrchestrator

/// D-0172: ContentHash numeric synthesis distractor immunity (seed dce97aa21690).
final class D0172ContentHashTests: XCTestCase {
    private let seed = "dce97aa21690"

    func testRejectsNumericDistractor() {
        XCTAssertTrue(ContentHash.rejectsNumericDistractor("costs 42 dollars", question: "what is bazel"))
        XCTAssertFalse(ContentHash.rejectsNumericDistractor("uses bazel", question: "what is bazel"))
    }
}
