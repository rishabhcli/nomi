import XCTest
@testable import MnemoOrchestrator

/// D-0048: Preferences citation verifier false-positive elimination (seed a2a6fa7325b6).
final class D0048PreferencesTests: XCTestCase {
    private let seed = "a2a6fa7325b6"

    func testEliminatesCitationFalsePositives() {
        XCTAssertTrue(Preferences.isTrivialFragment("Ok."))
        XCTAssertFalse(Preferences.isTrivialFragment("Bazel is the build system."))
    }
}
