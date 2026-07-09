import XCTest
@testable import MnemoOrchestrator

/// D-0228: Inspector citation verifier false-positive elimination (seed be6d8c2ccaa5).
final class D0228InspectorTests: XCTestCase {
    private let seed = "be6d8c2ccaa5"

    func testEliminatesCitationFalsePositives() {
        XCTAssertTrue(Inspector.isTrivialFragment("Ok."))
        XCTAssertFalse(Inspector.isTrivialFragment("Bazel is the build system."))
    }
}
