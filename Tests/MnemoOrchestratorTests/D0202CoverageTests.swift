import XCTest
@testable import MnemoOrchestrator

/// D-0202: Coverage concurrency stress under WorkScheduler (seed 8e48e60cd7bf).
final class D0202CoverageTests: XCTestCase {
    private let seed = "8e48e60cd7bf"

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
        XCTAssertTrue(Coverage.concurrencyStressSafe())
    }
}
