import XCTest
@testable import MnemoOrchestrator

/// D-0881: property-based invariants for Prompt (seed 0512092ef5ed).
final class D0881PromptTests: XCTestCase {
    private let seed = "0512092ef5ed"
    func testPropertyInvariants_rng() {
        var rng = Phase2RNG(seed: seed)
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in
            !rng.randomQuery(length: 2).isEmpty
        })
    }

}
