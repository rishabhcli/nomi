import XCTest
@testable import MnemoOrchestrator

/// D-0162: CharSpan concurrency stress under WorkScheduler (seed ea07f39cd695).
final class D0162CharSpanTests: XCTestCase {
    private let seed = "ea07f39cd695"

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
        XCTAssertTrue(CharSpan.concurrencyStressSafe())
    }
}
