import XCTest
@testable import MnemoOrchestrator

/// D-0841: property-based invariants for Profile (seed 987122b9ef0b).
final class D0841ProfileTests: XCTestCase {
    private let seed = "987122b9ef0b"
    func testPropertyInvariants_rng() {
        var rng = Phase2RNG(seed: seed)
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in
            !rng.randomQuery(length: 2).isEmpty
        })
    }

}
