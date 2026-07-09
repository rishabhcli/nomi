import XCTest
@testable import MnemoOrchestrator

/// D-0542: concurrency stress under WorkScheduler for AdaptiveEffort (seed 63f2d94cf74b).
final class D0542AdaptiveEffortTests: XCTestCase {
    private let seed = "63f2d94cf74b"

    func testConcurrency_stressSafe() {
        XCTAssertTrue(AdaptiveEffort.concurrencyStressSafe())
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
                group.addTask { AdaptiveEffort.concurrencyStressSafe() }
            }
            for await ok in group { XCTAssertTrue(ok) }
        }
    }
}
