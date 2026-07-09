import XCTest
@testable import MnemoOrchestrator

/// D-0025: Profile cache poisoning resistance (seed a76ebb452b51).
final class D0025ProfileTests: XCTestCase {
    private let seed = "a76ebb452b51"

    func testResistsCachePoisoning() {
        let poisoned = "fact https://api.supermemory.ai/evil"
        XCTAssertFalse(Profile.resistsCachePoisoning(poisoned))
        XCTAssertTrue(Profile.resistsCachePoisoning("local fact only"))
    }
}
