import XCTest
@testable import MnemoOrchestrator

/// D-0145: CommandParser cache poisoning resistance (seed 9c98d36e1a2f).
final class D0145CommandParserTests: XCTestCase {
    private let seed = "9c98d36e1a2f"

    func testResistsCachePoisoning() {
        let poisoned = "fact https://api.supermemory.ai/evil"
        XCTAssertFalse(CommandParser.resistsCachePoisoning(poisoned))
        XCTAssertTrue(CommandParser.resistsCachePoisoning("local fact only"))
    }
}
