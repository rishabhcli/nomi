import XCTest
@testable import MnemoOrchestrator

/// D-0956: subprocess stderr backpressure for TimelineBuilder (seed 2670a0992463).
final class D0956TimelineBuilderTests: XCTestCase {
    private let seed = "2670a0992463"
    func testStderrBackpressure_rng() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 10))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

}
