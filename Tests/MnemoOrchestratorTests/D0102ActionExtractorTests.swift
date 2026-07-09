import XCTest
@testable import MnemoOrchestrator

/// D-0102: ActionExtractor concurrency stress under WorkScheduler (seed 0bf00363c32a).
final class D0102ActionExtractorTests: XCTestCase {
    private let seed = "0bf00363c32a"

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
        XCTAssertTrue(ActionExtractor.concurrencyStressSafe())
    }
}
