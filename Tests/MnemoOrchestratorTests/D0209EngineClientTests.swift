import XCTest
@testable import MnemoOrchestrator

/// D-0209: EngineClient memory supersession race conditions (seed d14fe26f5f9e).
final class D0209EngineClientTests: XCTestCase {
    private let seed = "d14fe26f5f9e"

    func testSupersessionRaceSafe() {
        let k1 = EngineClient.supersessionKey(id: "a", version: 1)
        let k2 = EngineClient.supersessionKey(id: "a", version: 2)
        XCTAssertNotEqual(k1, k2)
        XCTAssertTrue(EngineClient.supersessionRaceSafe())
    }
}
