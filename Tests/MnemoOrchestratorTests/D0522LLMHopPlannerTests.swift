import XCTest
@testable import MnemoOrchestrator

/// D-0522: concurrency stress under WorkScheduler for LLMHopPlanner (seed 41897a615ccf).
final class D0522LLMHopPlannerTests: XCTestCase {
    private let seed = "41897a615ccf"

    func testConcurrency_stressSafe() {
        XCTAssertTrue(LLMHopPlanner.concurrencyStressSafe())
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
                group.addTask { LLMHopPlanner.concurrencyStressSafe() }
            }
            for await ok in group { XCTAssertTrue(ok) }
        }
    }
}
