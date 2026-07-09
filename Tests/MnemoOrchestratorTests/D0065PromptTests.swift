import XCTest
@testable import MnemoOrchestrator

/// D-0065: Prompt cache poisoning resistance (seed e57a9cb7a959).
final class D0065PromptTests: XCTestCase {
    private let seed = "e57a9cb7a959"

    func testResistsCachePoisoning() {
        let poisoned = "fact https://api.supermemory.ai/evil"
        XCTAssertFalse(Prompt.resistsCachePoisoning(poisoned))
        XCTAssertTrue(Prompt.resistsCachePoisoning("local fact only"))
    }
}
