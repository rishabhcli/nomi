import XCTest
@testable import MnemoOrchestrator

/// D-0787: router escalation boundaries for Consolidation (seed d1d89d61bbdc).
final class D0787ConsolidationTests: XCTestCase {
    private let seed = "d1d89d61bbdc"
    func testRouterEscalation_rng() {
        var rng = Phase2RNG(seed: seed)
        let r = HeuristicRouter().classify(rng.randomQuery(length: 3))
        XCTAssertTrue(Phase2Techniques.routerEscalationBounded(r))
    }

}
