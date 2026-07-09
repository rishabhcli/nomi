import XCTest
@testable import MnemoOrchestrator

/// D-0709: memory supersession race conditions for LocalExtractor (seed 6d4417770174).
final class D0709LocalExtractorTests: XCTestCase {
    private let seed = "6d4417770174"

    func testSupersession_raceSafe() {
        XCTAssertTrue(LocalExtractor.supersessionRaceSafe())
    }

    func testSupersession_keyVersioned() {
        let k1 = LocalExtractor.supersessionKey(id: "d", version: 1)
        let k2 = LocalExtractor.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }

    func testSupersession_phase2Safe() {
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }
}
