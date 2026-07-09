import XCTest
@testable import MnemoOrchestrator

/// D-0876: subprocess stderr backpressure for CharSpan (seed 42bc8932aeda).
final class D0876CharSpanTests: XCTestCase {
    private let seed = "42bc8932aeda"
    func testStderrBackpressure_rng() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 10))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

}
