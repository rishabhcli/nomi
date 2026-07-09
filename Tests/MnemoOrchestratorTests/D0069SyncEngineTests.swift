import XCTest
@testable import MnemoOrchestrator

/// D-0069: SyncEngine memory supersession race conditions (seed 6020cab37bd8).
final class D0069SyncEngineTests: XCTestCase {
    private let seed = "6020cab37bd8"

    func testSupersessionRaceSafe() {
        let k1 = SyncEngine.supersessionKey(id: "a", version: 1)
        let k2 = SyncEngine.supersessionKey(id: "a", version: 2)
        XCTAssertNotEqual(k1, k2)
        XCTAssertTrue(SyncEngine.supersessionRaceSafe())
    }
}
