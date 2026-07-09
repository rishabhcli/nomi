import XCTest
@testable import MnemoOrchestrator

/// D-0148: LocalExtractor citation verifier false-positive elimination (seed 527521255b54).
final class D0148LocalExtractorTests: XCTestCase {
    private let seed = "527521255b54"

    func testEliminatesCitationFalsePositives() {
        XCTAssertTrue(LocalExtractor.isTrivialFragment("Ok."))
        XCTAssertFalse(LocalExtractor.isTrivialFragment("Bazel is the build system."))
    }
}
