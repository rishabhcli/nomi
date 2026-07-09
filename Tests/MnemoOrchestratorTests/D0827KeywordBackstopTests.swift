import XCTest
@testable import MnemoOrchestrator

/// D-0827: router escalation boundaries for KeywordBackstop (seed 6e16e1ea8e3a).
final class D0827KeywordBackstopTests: XCTestCase {
    private let seed = "6e16e1ea8e3a"
    func testRouterEscalation_rng() {
        var rng = Phase2RNG(seed: seed)
        let r = HeuristicRouter().classify(rng.randomQuery(length: 3))
        XCTAssertTrue(Phase2Techniques.routerEscalationBounded(r))
    }

}
