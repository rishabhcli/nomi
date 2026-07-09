import XCTest
@testable import MnemoOrchestrator

/// D-0642: concurrency stress under WorkScheduler for QueryDecomposer (seed 3319dc566e8b).
final class D0642QueryDecomposerTests: XCTestCase {
    private let seed = "3319dc566e8b"

    func testConcurrency_stressSafe() {
        XCTAssertTrue(QueryDecomposer.concurrencyStressSafe())
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
    }

    func testConcurrency_schedulingYield() async {
        let scheduler = WorkScheduler()
        let token = await scheduler.beginInteractive()
        await WorkScheduler.Scheduling.yieldIfInteractiveWaiting(scheduler)
        await scheduler.endInteractive(token)
    }

    func testConcurrency_parallelLifecycle() async {
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<6 {
                group.addTask { QueryDecomposer.concurrencyStressSafe() }
            }
            for await ok in group { XCTAssertTrue(ok) }
        }
    }
}
