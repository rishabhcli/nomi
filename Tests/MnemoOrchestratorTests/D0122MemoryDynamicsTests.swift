import XCTest
@testable import MnemoOrchestrator

/// D-0122: MemoryDynamics concurrency stress under WorkScheduler (seed c9c1bad1a500).
final class D0122MemoryDynamicsTests: XCTestCase {
    private let seed = "c9c1bad1a500"

    func testConcurrencyStress_underScheduler() async {
        let scheduler = WorkScheduler()
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<6 {
                group.addTask {
                    await scheduler.runInteractive { 1 }
                    return 1
                }
            }
            var sum = 0
            for await v in group { sum += v }
            XCTAssertEqual(sum, 6)
        }
        XCTAssertFalse(await scheduler.shouldBackgroundYield)
        XCTAssertTrue(MemoryDynamics.concurrencyStressSafe())
    }
}
