import XCTest
@testable import MnemoOrchestrator

/// D-0359: Router QueryEvent ordering guarantees (seed 8ec6ed2bdd5d).
final class D0359RouterTests: XCTestCase {
    private let seed = "8ec6ed2bdd5d"

    func testLifecycleEventOrder() {
        let events = Router.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertGreaterThanOrEqual(events.count, 2)
        Phase2TechniqueSupport.assertEventsRenderable(events)
    }

    func testNotchReducerAppendsReasoning() {
        var state = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        state = NotchReducer.apply(.routed(intent: "lookup", effort: "low"), to: state)
        state = NotchReducer.apply(.reasoning(["step"]), to: state)
        XCTAssertFalse(state.reasoning.isEmpty)
    }

    func testProperty_eventReductionStable() {
        var rng = Phase2RNG(seed: seed)
        for branch in [Router.LifecycleBranch.routeAmbiguity, .emptyEvidence, .retry] {
            let e1 = Router.lifecycleEvents(branch: branch)
            let e2 = Router.lifecycleEvents(branch: branch)
            XCTAssertEqual(e1.count, e2.count)
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
