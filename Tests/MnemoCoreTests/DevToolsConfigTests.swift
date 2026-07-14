import XCTest
@testable import MnemoCore

/// The dev observability server is OFF by default and its port comes from
/// config (no hardcoded ports in code). It binds loopback only, so an invalid
/// port must fail validation like any other invariant breach.
final class DevToolsConfigTests: XCTestCase {

    func testDevToolsDefaultsOffOnStandardPort() throws {
        let c = try MnemoConfig.load(from: ConfigTests.sample)
        XCTAssertFalse(c.devtools.enabled)
        XCTAssertEqual(c.devtools.port, 7878)
    }

    func testDevToolsParsedWhenPresent() throws {
        let text = ConfigTests.sample + "\n[devtools]\nenabled = true\nport = 7900\n"
        let c = try MnemoConfig.load(from: text)
        XCTAssertTrue(c.devtools.enabled)
        XCTAssertEqual(c.devtools.port, 7900)
    }

    func testInvalidDevToolsPortRejected() throws {
        let text = ConfigTests.sample + "\n[devtools]\nenabled = true\nport = 70000\n"
        XCTAssertThrowsError(try MnemoConfig.load(from: text).validateInvariant())
    }

    func testUnknownDevToolsKeyRejected() {
        let text = ConfigTests.sample + "\n[devtools]\nenabled = true\nbind = \"0.0.0.0\"\n"
        XCTAssertThrowsError(try MnemoConfig.load(from: text))
    }
}
