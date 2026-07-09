import XCTest
@testable import MnemoOrchestrator

/// D-0719: QueryEvent ordering guarantees for EngineClient (seed 6cfcda601db1).
final class D0719EngineClientTests: XCTestCase {
    private let seed = "6cfcda601db1"

    func testOrdering_lifecycleValid() {
        let events = EngineClient.orderedLifecycleEvents()
        XCTAssertTrue(EngineClient.eventOrderingValid(events))
    }

    func testOrdering_phase2Lifecycle() {
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(
            EngineClient.lifecycleEvents(branch: .routeAmbiguity)))
    }

    func testOrdering_emptyEvidenceSourcesFirst() {
        let events = EngineClient.lifecycleEvents(branch: .emptyEvidence)
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }
        let tIdx = events.firstIndex { if case .token = $0 { true } else { false } }
        if let s = sIdx, let t = tIdx { XCTAssertLessThan(s, t) }
    }
}
