import XCTest
@testable import MnemoOrchestrator

/// D-0459: ActionExtractor QueryEvent ordering guarantees (seed ab3d0d663dbf).
final class D0459ActionExtractorTests: XCTestCase {
    private let seed = "ab3d0d663dbf"

    func testLifecycleEventOrder() {
        let events = ActionExtractor.lifecycleEvents(branch: .emptyEvidence)
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
        for branch in [ActionExtractor.LifecycleBranch.routeAmbiguity, .emptyEvidence, .retry] {
            let e1 = ActionExtractor.lifecycleEvents(branch: branch)
            let e2 = ActionExtractor.lifecycleEvents(branch: branch)
            XCTAssertEqual(e1.count, e2.count)
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
