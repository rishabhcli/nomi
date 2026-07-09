import XCTest
@testable import MnemoOrchestrator

/// D-0201: Preferences property-based invariants (seed bc5f6b15be43).
final class D0201PreferencesTests: XCTestCase {
    private let seed = "bc5f6b15be43"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<8 {
            let n = 1 + rng.nextInt(upperBound: 4)
            var evidence: [Retrieved] = []
            for i in 0..<n {
                evidence.append(Phase2Fixtures.hit("Preferences", i: i))
            }
            XCTAssertTrue(Preferences.propertyInvariantsHold(evidence))
        }
    }

    func testEmptyInputInvariant() {
        XCTAssertTrue(Preferences.propertyInvariantsHold([]))
    }
}
