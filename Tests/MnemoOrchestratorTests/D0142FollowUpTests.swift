import XCTest
@testable import MnemoOrchestrator

/// D-0142: FollowUp concurrency stress under WorkScheduler (seed 1022a90b9add).
final class D0142FollowUpTests: XCTestCase {
    private let seed = "1022a90b9add"

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
        XCTAssertTrue(FollowUp.concurrencyStressSafe())
    }
}
