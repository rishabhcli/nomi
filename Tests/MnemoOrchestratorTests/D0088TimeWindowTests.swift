import XCTest
@testable import MnemoOrchestrator

/// D-0088: TimeWindow citation verifier false-positive elimination (seed 15aae7bc0528).
final class D0088TimeWindowTests: XCTestCase {
    private let seed = "15aae7bc0528"

    func testEliminatesCitationFalsePositives() {
        XCTAssertTrue(TimeWindow.isTrivialFragment("Ok."))
        XCTAssertFalse(TimeWindow.isTrivialFragment("Bazel is the build system."))
    }
}
