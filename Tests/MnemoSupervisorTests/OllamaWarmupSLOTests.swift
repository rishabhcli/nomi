import XCTest
@testable import MnemoSupervisor

final class OllamaWarmupSLOTests: XCTestCase {
    func testWarmupWithinSLO() {
        let r = OllamaWarmupSLO.evaluate(model: "gpt-oss:20b", warmupMs: 12_000)
        XCTAssertTrue(r.passed)
    }

    func testWarmupExceedsSLO() {
        let r = OllamaWarmupSLO.evaluate(model: "gpt-oss:20b", warmupMs: 90_000, sloMs: 60_000)
        XCTAssertFalse(r.passed)
    }
}
