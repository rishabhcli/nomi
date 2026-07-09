import XCTest
@testable import MnemoOrchestrator

/// D-0101: Highlight property-based invariants (seed f33cf744bdca).
final class D0101HighlightTests: XCTestCase {
    private let seed = "f33cf744bdca"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<8 {
            let n = 1 + rng.nextInt(upperBound: 4)
            var evidence: [Retrieved] = []
            for i in 0..<n {
                evidence.append(Phase2Fixtures.hit("Highlight", i: i))
            }
            XCTAssertTrue(Highlight.propertyInvariantsHold(evidence))
        }
    }

    func testEmptyInputInvariant() {
        XCTAssertTrue(Highlight.propertyInvariantsHold([]))
    }
}
