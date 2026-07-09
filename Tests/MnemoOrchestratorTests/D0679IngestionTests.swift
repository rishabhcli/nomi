import XCTest
@testable import MnemoOrchestrator

/// D-0679: QueryEvent ordering guarantees for Ingestion (seed db21e12a2f4d).
final class D0679IngestionTests: XCTestCase {
    private let seed = "db21e12a2f4d"

    func testOrdering_lifecycleValid() {
        let events = Ingestion.orderedLifecycleEvents()
        XCTAssertTrue(Ingestion.eventOrderingValid(events))
    }

    func testOrdering_phase2Lifecycle() {
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(
            Ingestion.lifecycleEvents(branch: .routeAmbiguity)))
    }

    func testOrdering_emptyEvidenceSourcesFirst() {
        let events = Ingestion.lifecycleEvents(branch: .emptyEvidence)
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }
        let tIdx = events.firstIndex { if case .token = $0 { true } else { false } }
        if let s = sIdx, let t = tIdx { XCTAssertLessThan(s, t) }
    }
}
