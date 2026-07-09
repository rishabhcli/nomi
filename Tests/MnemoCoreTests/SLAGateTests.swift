import XCTest
@testable import MnemoCore

final class SLAGateTests: XCTestCase {
    func testFirstTokenPass() throws {
        let c = try MnemoConfig.load(from: ConfigTests.sample)
        let r = SLAGate.checkFirstToken(observedMs: 1200, config: c)
        XCTAssertTrue(r.passed)
        XCTAssertEqual(r.limitMs, 1500)
    }

    func testFirstTokenFail() throws {
        let c = try MnemoConfig.load(from: ConfigTests.sample)
        let r = SLAGate.checkFirstToken(observedMs: 2000, config: c)
        XCTAssertFalse(r.passed)
    }

    func testP95RegressionGate() {
        XCTAssertFalse(SLAGate.regressionFailed(samplesMs: [800, 900, 1000, 1100, 2000], limitMs: 1500))
        XCTAssertTrue(SLAGate.regressionFailed(samplesMs: [800, 900, 1000, 1100, 3000], limitMs: 1500))
    }
}
