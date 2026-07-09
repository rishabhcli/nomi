import XCTest
@testable import MnemoOrchestrator

/// D-0161: SpanResolver property-based invariants (seed 726b35a092ab).
final class D0161SpanResolverTests: XCTestCase {
    private let seed = "726b35a092ab"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<8 {
            let n = 1 + rng.nextInt(upperBound: 4)
            var evidence: [Retrieved] = []
            for i in 0..<n {
                evidence.append(Phase2Fixtures.hit("SpanResolver", i: i))
            }
            XCTAssertTrue(SpanResolver.propertyInvariantsHold(evidence))
        }
    }

    func testEmptyInputInvariant() {
        XCTAssertTrue(SpanResolver.propertyInvariantsHold([]))
    }
}
