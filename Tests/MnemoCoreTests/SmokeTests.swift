import XCTest
@testable import MnemoCore

final class SmokeTests: XCTestCase {
    func testVersionExists() { XCTAssertEqual(Mnemo.version, "0.0.0") }
}
