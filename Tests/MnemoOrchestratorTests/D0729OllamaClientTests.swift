import XCTest
@testable import MnemoOrchestrator

/// D-0729: memory supersession race conditions for OllamaClient (seed 5c8bf5912f14).
final class D0729OllamaClientTests: XCTestCase {
    private let seed = "5c8bf5912f14"

    func testSupersession_raceSafe() {
        XCTAssertTrue(OllamaClient.supersessionRaceSafe())
    }

    func testSupersession_keyVersioned() {
        let k1 = OllamaClient.supersessionKey(id: "d", version: 1)
        let k2 = OllamaClient.supersessionKey(id: "d", version: 2)
        XCTAssertNotEqual(k1, k2)
    }

    func testSupersession_phase2Safe() {
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [Phase2TestSupport.sampleMemory()]))
    }
}
