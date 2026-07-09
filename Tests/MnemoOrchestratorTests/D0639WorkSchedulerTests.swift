import XCTest
@testable import MnemoOrchestrator

/// D-0639: QueryEvent ordering guarantees for WorkScheduler (seed 507b42d646cb).
final class D0639WorkSchedulerTests: XCTestCase {
    private let seed = "507b42d646cb"

    func testOrdering_lifecycleValid() {
        let events = WorkScheduler.orderedLifecycleEvents()
        XCTAssertTrue(WorkScheduler.eventOrderingValid(events))
    }

    func testOrdering_phase2Lifecycle() {
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(
            WorkScheduler.lifecycleEvents(branch: .routeAmbiguity)))
    }

    func testOrdering_emptyEvidenceSourcesFirst() {
        let events = WorkScheduler.lifecycleEvents(branch: .emptyEvidence)
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }
        let tIdx = events.firstIndex { if case .token = $0 { true } else { false } }
        if let s = sIdx, let t = tIdx { XCTAssertLessThan(s, t) }
    }
}
