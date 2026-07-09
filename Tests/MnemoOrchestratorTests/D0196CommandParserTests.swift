import XCTest
@testable import MnemoOrchestrator

/// D-0196: CommandParser subprocess stderr backpressure (seed 4fc0439ef165).
final class D0196CommandParserTests: XCTestCase {
    private let seed = "4fc0439ef165"

    func testDrainsSubprocessStderr() {
        XCTAssertTrue(CommandParser.drainsSubprocessStderr())
    }
}
