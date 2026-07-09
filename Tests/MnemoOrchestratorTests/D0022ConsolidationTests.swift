import XCTest
@testable import MnemoOrchestrator

/// D-0022: Consolidation concurrency stress under WorkScheduler (seed dcf798c5a27f).
final class D0022ConsolidationTests: XCTestCase {
    private let seed = "dcf798c5a27f"

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
        XCTAssertTrue(Consolidation.concurrencyStressSafe())
    }
}
