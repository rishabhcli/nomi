import XCTest
@testable import MnemoOrchestrator

/// D-0192: ResponseStyle numeric synthesis distractor immunity (seed e4c266b71ce6).
final class D0192ResponseStyleTests: XCTestCase {
    private let seed = "e4c266b71ce6"

    func testRejectsNumericDistractor() {
        XCTAssertTrue(ResponseStyle.rejectsNumericDistractor("costs 42 dollars", question: "what is bazel"))
        XCTAssertFalse(ResponseStyle.rejectsNumericDistractor("uses bazel", question: "what is bazel"))
    }
}
