import XCTest
@testable import MnemoOrchestrator

/// D-0062: KeywordBackstop concurrency stress under WorkScheduler (seed b57899c9babc).
final class D0062KeywordBackstopTests: XCTestCase {
    private let seed = "b57899c9babc"

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
        XCTAssertTrue(KeywordBackstop.concurrencyStressSafe())
    }
}
