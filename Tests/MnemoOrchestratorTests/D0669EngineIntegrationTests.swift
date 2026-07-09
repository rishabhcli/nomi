import XCTest
@testable import MnemoOrchestrator

/// D-0669: memory supersession race conditions for EngineIntegration (seed f678e87f65c2).
final class D0669EngineIntegrationTests: XCTestCase {
    private let seed = "f678e87f65c2"

    func testSupersession_raceSafe() {
        XCTAssertTrue(EngineIntegration.supersessionRaceSafe())
    }

    func testSupersession_keyVersioned() {
        let k1 = EngineIntegration.supersessionKey(id: "d", version: 1)
        let k2 = EngineIntegration.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }

    func testSupersession_phase2Safe() {
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }
}
