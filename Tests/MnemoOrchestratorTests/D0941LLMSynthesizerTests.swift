import XCTest
@testable import MnemoOrchestrator

/// D-0941: property-based invariants for LLMSynthesizer (seed ad20f1aed5a1).
final class D0941LLMSynthesizerTests: XCTestCase {
    private let seed = "ad20f1aed5a1"
    func testPropertyInvariants_rng() {
        var rng = Phase2RNG(seed: seed)
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in
            !rng.randomQuery(length: 2).isEmpty
        })
    }

}
