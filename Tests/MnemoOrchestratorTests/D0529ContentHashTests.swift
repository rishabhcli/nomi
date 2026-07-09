import XCTest
@testable import MnemoOrchestrator

/// D-0529: memory supersession race conditions for ContentHash (seed a3c46704904e).
final class D0529ContentHashTests: XCTestCase {
    private let seed = "a3c46704904e"

    func testSupersession_raceSafe() {
        XCTAssertTrue(ContentHash.supersessionRaceSafe())
    }

    func testSupersession_keyVersioned() {
        let k1 = ContentHash.supersessionKey(id: "d", version: 1)
        let k2 = ContentHash.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }

    func testSupersession_phase2Safe() {
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }
}
