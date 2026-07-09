import XCTest
@testable import MnemoOrchestrator

/// D-0622: concurrency stress under WorkScheduler for AgenticGrep (seed 1c72d09efd55).
final class D0622AgenticGrepTests: XCTestCase {
    private let seed = "1c72d09efd55"

    func testConcurrency_stressSafe() {
        XCTAssertTrue(AgenticGrep.concurrencyStressSafe())
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
                group.addTask { AgenticGrep.concurrencyStressSafe() }
            }
            for await ok in group { XCTAssertTrue(ok) }
        }
    }
}
