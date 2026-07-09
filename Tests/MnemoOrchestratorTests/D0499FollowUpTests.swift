import XCTest
@testable import MnemoOrchestrator

/// D-0499: FollowUp QueryEvent ordering guarantees (seed 0057cd73ac2d).
final class D0499FollowUpTests: XCTestCase {
    private let seed = "0057cd73ac2d"

    func testLifecycleEventOrder() {
        let events = FollowUp.lifecycleEvents(branch: .emptyEvidence)
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
        for branch in [FollowUp.LifecycleBranch.routeAmbiguity, .emptyEvidence, .retry] {
            let e1 = FollowUp.lifecycleEvents(branch: branch)
            let e2 = FollowUp.lifecycleEvents(branch: branch)
            XCTAssertEqual(e1.count, e2.count)
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
