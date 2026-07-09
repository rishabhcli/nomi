import XCTest
@testable import MnemoOrchestrator

/// D-0181: NotchReducer property-based invariants (seed 240bf4309de7).
final class D0181NotchReducerTests: XCTestCase {
    private let seed = "240bf4309de7"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<8 {
            let n = 1 + rng.nextInt(upperBound: 4)
            var evidence: [Retrieved] = []
            for i in 0..<n {
                evidence.append(Phase2Fixtures.hit("NotchReducer", i: i))
            }
            XCTAssertTrue(NotchReducer.propertyInvariantsHold(evidence))
        }
    }

    func testEmptyInputInvariant() {
        XCTAssertTrue(NotchReducer.propertyInvariantsHold([]))
    }
}
