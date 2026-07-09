import XCTest
@testable import MnemoOrchestrator

/// D-0061: AgenticGrep property-based invariants (seed 584be303031c).
final class D0061AgenticGrepTests: XCTestCase {
    private let seed = "584be303031c"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<8 {
            let n = 1 + rng.nextInt(upperBound: 4)
            var evidence: [Retrieved] = []
            for i in 0..<n {
                evidence.append(Phase2Fixtures.hit("AgenticGrep", i: i))
            }
            XCTAssertTrue(AgenticGrep.propertyInvariantsHold(evidence))
        }
    }

    func testEmptyInputInvariant() {
        XCTAssertTrue(AgenticGrep.propertyInvariantsHold([]))
    }
}
