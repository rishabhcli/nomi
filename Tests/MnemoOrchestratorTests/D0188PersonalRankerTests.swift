import XCTest
@testable import MnemoOrchestrator

/// D-0188: PersonalRanker citation verifier false-positive elimination (seed 8bb66b0c2efd).
final class D0188PersonalRankerTests: XCTestCase {
    private let seed = "8bb66b0c2efd"

    func testEliminatesCitationFalsePositives() {
        XCTAssertTrue(PersonalRanker.isTrivialFragment("Ok."))
        XCTAssertFalse(PersonalRanker.isTrivialFragment("Bazel is the build system."))
    }
}
