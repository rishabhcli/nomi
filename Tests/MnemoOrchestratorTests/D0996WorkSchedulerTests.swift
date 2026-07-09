import XCTest
@testable import MnemoOrchestrator

/// D-0996: subprocess stderr backpressure for WorkScheduler (seed ae19bcb50d22).
final class D0996WorkSchedulerTests: XCTestCase {
    private let seed = "ae19bcb50d22"
    func testStderrBackpressure_rng() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 10))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

}
