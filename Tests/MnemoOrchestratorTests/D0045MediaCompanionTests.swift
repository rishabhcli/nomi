import XCTest
@testable import MnemoOrchestrator

/// D-0045: MediaCompanion cache poisoning resistance (seed 7a8e49d6fca9).
final class D0045MediaCompanionTests: XCTestCase {
    private let seed = "7a8e49d6fca9"

    func testResistsCachePoisoning() {
        let poisoned = "fact https://api.supermemory.ai/evil"
        XCTAssertFalse(MediaCompanion.resistsCachePoisoning(poisoned))
        XCTAssertTrue(MediaCompanion.resistsCachePoisoning("local fact only"))
    }
}
