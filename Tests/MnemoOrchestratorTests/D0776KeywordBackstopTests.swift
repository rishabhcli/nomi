import XCTest
@testable import MnemoOrchestrator

/// D-0776: subprocess stderr backpressure for KeywordBackstop (seed 62cca9ba9755).
final class D0776KeywordBackstopTests: XCTestCase {
    private let seed = "62cca9ba9755"
    func testStderrBackpressure_rng() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 10))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

}
