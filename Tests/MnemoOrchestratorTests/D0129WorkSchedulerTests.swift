import XCTest
@testable import MnemoOrchestrator

/// D-0129: WorkScheduler memory supersession race conditions (seed 8719f36ab1f1).
final class D0129WorkSchedulerTests: XCTestCase {
    private let seed = "8719f36ab1f1"

    func testSupersessionRaceSafe() {
        let k1 = WorkScheduler.supersessionKey(id: "a", version: 1)
        let k2 = WorkScheduler.supersessionKey(id: "a", version: 2)
        XCTAssertNotEqual(k1, k2)
        XCTAssertTrue(WorkScheduler.supersessionRaceSafe())
    }
}
