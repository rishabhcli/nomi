import XCTest
@testable import MnemoOrchestrator

/// D-0856: subprocess stderr backpressure for FollowUp (seed 1d2d35eebe19).
final class D0856FollowUpTests: XCTestCase {
    private let seed = "1d2d35eebe19"
    func testStderrBackpressure_rng() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 10))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

}
