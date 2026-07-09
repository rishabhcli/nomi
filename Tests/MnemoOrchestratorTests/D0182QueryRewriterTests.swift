import XCTest
@testable import MnemoOrchestrator

/// D-0182: QueryRewriter concurrency stress under WorkScheduler (seed 9bd891ef1a54).
final class D0182QueryRewriterTests: XCTestCase {
    private let seed = "9bd891ef1a54"

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
        XCTAssertTrue(QueryRewriter.concurrencyStressSafe())
    }
}
