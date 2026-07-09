import XCTest
@testable import MnemoOrchestrator

/// D-0816: subprocess stderr backpressure for ActionExtractor (seed df2ed4f5cfe2).
final class D0816ActionExtractorTests: XCTestCase {
    private let seed = "df2ed4f5cfe2"
    func testStderrBackpressure_rng() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 10))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

}
