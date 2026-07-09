import XCTest
@testable import MnemoOrchestrator

/// D-0947: router escalation boundaries for QueryRewriter (seed a7d674585624).
final class D0947QueryRewriterTests: XCTestCase {
    private let seed = "a7d674585624"
    func testRouterEscalation_rng() {
        var rng = Phase2RNG(seed: seed)
        let r = HeuristicRouter().classify(rng.randomQuery(length: 3))
        XCTAssertTrue(Phase2Techniques.routerEscalationBounded(r))
    }

}
