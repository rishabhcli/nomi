import XCTest
@testable import MnemoOrchestrator

/// D-0739: QueryEvent ordering guarantees for Profile (seed 422f57fd2c9a).
final class D0739ProfileTests: XCTestCase {
    private let seed = "422f57fd2c9a"

    func testOrdering_lifecycleValid() {
        let events = Profile.orderedLifecycleEvents()
        XCTAssertTrue(Profile.eventOrderingValid(events))
    }

    func testOrdering_phase2Lifecycle() {
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(
            Profile.lifecycleEvents(branch: .routeAmbiguity)))
    }

    func testOrdering_emptyEvidenceSourcesFirst() {
        let events = Profile.lifecycleEvents(branch: .emptyEvidence)
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }
        let tIdx = events.firstIndex { if case .token = $0 { true } else { false } }
        if let s = sIdx, let t = tIdx { XCTAssertLessThan(s, t) }
    }
}
