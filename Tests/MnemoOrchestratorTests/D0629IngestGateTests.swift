import XCTest
@testable import MnemoOrchestrator

/// D-0629: memory supersession race conditions for IngestGate (seed 7564ef5cbc83).
final class D0629IngestGateTests: XCTestCase {
    private let seed = "7564ef5cbc83"

    func testSupersession_raceSafe() {
        XCTAssertTrue(IngestGate.supersessionRaceSafe())
    }

    func testSupersession_keyVersioned() {
        let k1 = IngestGate.supersessionKey(id: "d", version: 1)
        let k2 = IngestGate.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }

    func testSupersession_phase2Safe() {
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }
}
