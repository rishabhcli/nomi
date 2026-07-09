import XCTest
@testable import MnemoOrchestrator

/// D-0662: concurrency stress under WorkScheduler for Highlight (seed 23ca94cee078).
final class D0662HighlightTests: XCTestCase {
    private let seed = "23ca94cee078"

    func testConcurrency_stressSafe() {
        XCTAssertTrue(Highlight.concurrencyStressSafe())
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
                group.addTask { Highlight.concurrencyStressSafe() }
            }
            for await ok in group { XCTAssertTrue(ok) }
        }
    }
}
