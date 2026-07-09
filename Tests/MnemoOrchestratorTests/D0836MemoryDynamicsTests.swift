import XCTest
@testable import MnemoOrchestrator

/// D-0836: subprocess stderr backpressure for MemoryDynamics (seed 3996a2719c41).
final class D0836MemoryDynamicsTests: XCTestCase {
    private let seed = "3996a2719c41"
    func testStderrBackpressure_rng() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 10))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

}
