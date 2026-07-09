import XCTest
@testable import MnemoOrchestrator

/// D-0559: QueryEvent ordering guarantees for Coverage (seed 8faa254a49c8).
final class D0559CoverageTests: XCTestCase {
    private let seed = "8faa254a49c8"

    func testOrdering_lifecycleValid() {
        let events = Coverage.orderedLifecycleEvents()
        XCTAssertTrue(Coverage.eventOrderingValid(events))
    }

    func testOrdering_phase2Lifecycle() {
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(
            Coverage.lifecycleEvents(branch: .routeAmbiguity)))
    }

    func testOrdering_emptyEvidenceSourcesFirst() {
        let events = Coverage.lifecycleEvents(branch: .emptyEvidence)
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }
        let tIdx = events.firstIndex { if case .token = $0 { true } else { false } }
        if let s = sIdx, let t = tIdx { XCTAssertLessThan(s, t) }
    }
}
