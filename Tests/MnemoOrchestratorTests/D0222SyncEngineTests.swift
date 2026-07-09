import XCTest
@testable import MnemoOrchestrator

/// D-0222: SyncEngine concurrency stress under WorkScheduler (seed 29ca1169afda).
final class D0222SyncEngineTests: XCTestCase {
    private let seed = "29ca1169afda"

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
        XCTAssertTrue(SyncEngine.concurrencyStressSafe())
    }
}
