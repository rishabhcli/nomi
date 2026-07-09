import XCTest
@testable import MnemoOrchestrator

/// D-0952: numeric synthesis distractor immunity for QueryHistory (seed 7ba5fdf99d63).
final class D0952QueryHistoryTests: XCTestCase {
    private let seed = "7ba5fdf99d63"
    func testNumericDistractorImmunity_rng() {
        var rng = Phase2RNG(seed: seed)
        let evidence = [Retrieved(memory: "count is 42 items", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        let claim = rng.randomQuery(length: 3)
        XCTAssertTrue(Phase2Techniques.immuneToNumericDistractor(claim: claim, evidence: evidence, distractor: "99"))
        XCTAssertTrue(NumericReasoner.isNumericQuestion("how many items?"))
    }

}
