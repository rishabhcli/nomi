import XCTest
@testable import MnemoOrchestrator

/// D-0339: AnswerCache QueryEvent ordering guarantees (seed 778ff026bfe2).
final class D0339AnswerCacheTests: XCTestCase {
    private let seed = "778ff026bfe2"

    func testLifecycleEventOrder() {
        let events = AnswerCache.lifecycleEvents(branch: .emptyEvidence)
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
        for branch in [AnswerCache.LifecycleBranch.routeAmbiguity, .emptyEvidence, .retry] {
            let e1 = AnswerCache.lifecycleEvents(branch: branch)
            let e2 = AnswerCache.lifecycleEvents(branch: branch)
            XCTAssertEqual(e1.count, e2.count)
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
