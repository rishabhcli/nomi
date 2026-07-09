import XCTest
@testable import MnemoOrchestrator

/// D-0028: NotchReducer citation verifier false-positive elimination (seed 8c526c68a54e).
final class D0028NotchReducerTests: XCTestCase {
    private let seed = "8c526c68a54e"

    func testEliminatesCitationFalsePositives() {
        XCTAssertTrue(NotchReducer.isTrivialFragment("Ok."))
        XCTAssertFalse(NotchReducer.isTrivialFragment("Bazel is the build system."))
    }
}
