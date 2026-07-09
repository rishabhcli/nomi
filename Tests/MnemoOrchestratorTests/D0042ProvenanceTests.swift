import XCTest
@testable import MnemoOrchestrator

/// D-0042: Provenance concurrency stress under WorkScheduler (seed 5c2083671b10).
final class D0042ProvenanceTests: XCTestCase {
    private let seed = "5c2083671b10"

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
        XCTAssertTrue(Provenance.concurrencyStressSafe())
    }
}
