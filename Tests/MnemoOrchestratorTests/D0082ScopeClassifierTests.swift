import XCTest
@testable import MnemoOrchestrator

/// D-0082: ScopeClassifier concurrency stress under WorkScheduler (seed 328e578e68af).
final class D0082ScopeClassifierTests: XCTestCase {
    private let seed = "328e578e68af"

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
        XCTAssertTrue(ScopeClassifier.concurrencyStressSafe())
    }
}
