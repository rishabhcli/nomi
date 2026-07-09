import XCTest
@testable import MnemoCore

final class InvariantTests: XCTestCase {
    func testValidConfigPasses() throws {
        try MnemoConfig.load(from: ConfigTests.sample).validateInvariant()
    }

    func testNonLoopbackEngineRejected() throws {
        let bad = ConfigTests.sample.replacingOccurrences(
            of: "base_url = \"http://127.0.0.1:6767\"",
            with: "base_url = \"http://api.supermemory.ai\"")
        XCTAssertThrowsError(try MnemoConfig.load(from: bad).validateInvariant()) { err in
            XCTAssertEqual(err as? ConfigError, .notLoopback(field: "engine.base_url", value: "http://api.supermemory.ai"))
        }
    }

    func testLANModelRuntimeRejected() throws {
        let bad = ConfigTests.sample.replacingOccurrences(
            of: "runtime_base_url = \"http://127.0.0.1:11434\"",
            with: "runtime_base_url = \"http://192.168.1.50:11434\"")
        XCTAssertThrowsError(try MnemoConfig.load(from: bad).validateInvariant()) { err in
            XCTAssertEqual(err as? ConfigError, .notLoopback(field: "model.runtime_base_url", value: "http://192.168.1.50:11434"))
        }
    }

    func testBackingStoreMismatchRejected() throws {
        let bad = ConfigTests.sample.replacingOccurrences(
            of: "backing_store = \"http://127.0.0.1:6767\"",
            with: "backing_store = \"http://127.0.0.1:9999\"")
        XCTAssertThrowsError(try MnemoConfig.load(from: bad).validateInvariant()) { err in
            XCTAssertEqual(err as? ConfigError, .backingStoreMismatch(backing: "http://127.0.0.1:9999", engine: "http://127.0.0.1:6767"))
        }
    }

    func testExitCodeContract() {
        XCTAssertEqual(MnemoExitCode.ok.rawValue, 0)
        XCTAssertEqual(MnemoExitCode.invariantViolation.rawValue, 3)
    }

    func testIsLoopback() {
        XCTAssertTrue(isLoopback(URL(string: "http://127.0.0.1:6767")!))
        XCTAssertTrue(isLoopback(URL(string: "http://localhost:11434")!))
        XCTAssertFalse(isLoopback(URL(string: "http://0.0.0.0:6767")!))
        XCTAssertFalse(isLoopback(URL(string: "https://api.supermemory.ai")!))
        XCTAssertFalse(isLoopback(URL(string: "http://192.168.1.1:6767")!))
        XCTAssertFalse(isLoopback(URL(string: "http://10.0.0.1:6767")!))
    }
}
