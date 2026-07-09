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
}
