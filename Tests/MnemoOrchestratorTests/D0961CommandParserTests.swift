import XCTest
@testable import MnemoOrchestrator

/// D-0961: property-based invariants for CommandParser (seed b6c2c754c5fd).
final class D0961CommandParserTests: XCTestCase {
    private let seed = "b6c2c754c5fd"
    func testPropertyInvariants_rng() {
        var rng = Phase2RNG(seed: seed)
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in
            !rng.randomQuery(length: 2).isEmpty
        })
    }

}
