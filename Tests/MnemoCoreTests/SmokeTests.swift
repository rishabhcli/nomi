import XCTest
@testable import MnemoCore

final class SmokeTests: XCTestCase {
    func testVersionExists() {
        XCTAssertFalse(Mnemo.version.isEmpty)
        XCTAssertNotEqual(Mnemo.version, "0.0.0", "release builds must not ship the initial placeholder version")
    }
}
