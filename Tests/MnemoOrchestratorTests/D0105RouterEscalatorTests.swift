import XCTest
@testable import MnemoOrchestrator

/// D-0105: RouterEscalator cache poisoning resistance (seed 8630187c6cca).
final class D0105RouterEscalatorTests: XCTestCase {
    private let seed = "8630187c6cca"

    func testResistsCachePoisoning() {
        let poisoned = "fact https://api.supermemory.ai/evil"
        XCTAssertFalse(RouterEscalator.resistsCachePoisoning(poisoned))
        XCTAssertTrue(RouterEscalator.resistsCachePoisoning("local fact only"))
    }
}
