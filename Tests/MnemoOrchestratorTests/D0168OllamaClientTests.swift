import XCTest
@testable import MnemoOrchestrator

/// D-0168: OllamaClient citation verifier false-positive elimination (seed 53ca74b28e8e).
final class D0168OllamaClientTests: XCTestCase {
    private let seed = "53ca74b28e8e"

    func testEliminatesCitationFalsePositives() {
        XCTAssertTrue(OllamaClient.isTrivialFragment("Ok."))
        XCTAssertFalse(OllamaClient.isTrivialFragment("Bazel is the build system."))
    }
}
