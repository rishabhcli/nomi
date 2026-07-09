import XCTest
@testable import MnemoOrchestrator

/// D-0602: concurrency stress under WorkScheduler for Confidence (seed 92f48d07e219).
final class D0602ConfidenceTests: XCTestCase {
    private let seed = "92f48d07e219"

    func testConcurrency_stressSafe() {
        XCTAssertTrue(Confidence.concurrencyStressSafe())
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
                group.addTask { Confidence.concurrencyStressSafe() }
            }
            for await ok in group { XCTAssertTrue(ok) }
        }
    }
}
