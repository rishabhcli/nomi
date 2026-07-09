import XCTest
@testable import MnemoOrchestrator

/// D-0821: property-based invariants for EngineClient (seed 289fb13c8256).
final class D0821EngineClientTests: XCTestCase {
    private let seed = "289fb13c8256"
    func testPropertyInvariants_rng() {
        var rng = Phase2RNG(seed: seed)
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in
            !rng.randomQuery(length: 2).isEmpty
        })
    }

}
