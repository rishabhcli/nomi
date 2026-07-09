import XCTest
@testable import MnemoOrchestrator

/// D-0756: subprocess stderr backpressure for Provenance (seed 4bf302ee8a8d).
final class D0756ProvenanceTests: XCTestCase {
    private let seed = "4bf302ee8a8d"
    func testStderrBackpressure_rng() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 10))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

}
