import XCTest
@testable import MnemoCore

final class StackHealthTests: XCTestCase {
    func testLoopbackDetection() {
        XCTAssertTrue(ProcessState(name: "e", isRunning: true, boundAddress: "127.0.0.1:6767").isLoopback)
        XCTAssertFalse(ProcessState(name: "e", isRunning: true, boundAddress: "0.0.0.0:6767").isLoopback)
        XCTAssertFalse(ProcessState(name: "e", isRunning: true, boundAddress: nil).isLoopback)
    }

    func testAllHealthy() {
        let ok = ProcessState(name: "x", isRunning: true, boundAddress: "127.0.0.1:1")
        XCTAssertTrue(StackHealth(ollama: ok, engine: ok, smfs: ok).allHealthyAndLoopback)
        let down = ProcessState(name: "x", isRunning: false, boundAddress: nil)
        XCTAssertFalse(StackHealth(ollama: ok, engine: down, smfs: ok).allHealthyAndLoopback)
    }

    func testUnhealthyReasons() {
        let ok = ProcessState(name: "ollama", isRunning: true, boundAddress: "127.0.0.1:11434")
        let down = ProcessState(name: "engine", isRunning: false, boundAddress: nil)
        let bad = ProcessState(name: "smfs", isRunning: true, boundAddress: "0.0.0.0:11111")
        let h = StackHealth(ollama: ok, engine: down, smfs: bad)
        XCTAssertEqual(h.unhealthyReasons, [
            "engine not running",
            "smfs bound to non-loopback 0.0.0.0:11111"
        ])
    }

    func testAdditionalHealthFailurePreventsGreenStatus() {
        let ok = ProcessState(name: "x", isRunning: true, boundAddress: "127.0.0.1:1")
        let h = StackHealth(
            ollama: ok,
            engine: ok,
            smfs: ok,
            additionalUnhealthyReasons: ["engine persistence snapshot failed"]
        )

        XCTAssertFalse(h.allHealthyAndLoopback)
        XCTAssertEqual(h.unhealthyReasons, ["engine persistence snapshot failed"])
    }
}
