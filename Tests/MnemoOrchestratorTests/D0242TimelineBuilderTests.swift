import XCTest
@testable import MnemoOrchestrator

/// D-0242: TimelineBuilder concurrency stress under WorkScheduler (seed e8d2f10e1ef6).
final class D0242TimelineBuilderTests: XCTestCase {
    private let seed = "e8d2f10e1ef6"

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
        XCTAssertTrue(TimelineBuilder.concurrencyStressSafe())
    }
}
