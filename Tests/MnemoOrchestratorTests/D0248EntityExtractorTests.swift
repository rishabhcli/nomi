import XCTest
@testable import MnemoOrchestrator

/// D-0248: EntityExtractor citation verifier false-positive elimination (seed 9d74647f8bf1).
final class D0248EntityExtractorTests: XCTestCase {
    private let seed = "9d74647f8bf1"

    func testEliminatesCitationFalsePositives() {
        XCTAssertTrue(EntityExtractor.isTrivialFragment("Ok."))
        XCTAssertFalse(EntityExtractor.isTrivialFragment("Bazel is the build system."))
    }
}
