import XCTest
@testable import MnemoOrchestrator

/// D-0896: subprocess stderr backpressure for QueryRewriter (seed aaefe82cf673).
final class D0896QueryRewriterTests: XCTestCase {
    private let seed = "aaefe82cf673"
    func testStderrBackpressure_rng() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 10))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

}
