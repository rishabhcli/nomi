import XCTest
@testable import MnemoOrchestrator

/// D-0128: EgressGuard citation verifier false-positive elimination (seed 201c528f8604).
final class D0128EgressGuardTests: XCTestCase {
    private let seed = "201c528f8604"

    func testEliminatesCitationFalsePositives() {
        XCTAssertTrue(EgressGuard.isTrivialFragment("Ok."))
        XCTAssertFalse(EgressGuard.isTrivialFragment("Bazel is the build system."))
    }
}
