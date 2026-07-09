import XCTest
@testable import MnemoOrchestrator

/// D-0936: subprocess stderr backpressure for SyncEngine (seed 85fa9f64e847).
final class D0936SyncEngineTests: XCTestCase {
    private let seed = "85fa9f64e847"
    func testStderrBackpressure_rng() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 10))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

}
