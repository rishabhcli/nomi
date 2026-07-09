import XCTest
@testable import MnemoOrchestrator

/// D-0569: memory supersession race conditions for SpanResolver (seed e482ed68713c).
final class D0569SpanResolverTests: XCTestCase {
    private let seed = "e482ed68713c"

    func testSupersession_raceSafe() {
        XCTAssertTrue(SpanResolver.supersessionRaceSafe())
    }

    func testSupersession_keyVersioned() {
        let k1 = SpanResolver.supersessionKey(id: "d", version: 1)
        let k2 = SpanResolver.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }

    func testSupersession_phase2Safe() {
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }
}
