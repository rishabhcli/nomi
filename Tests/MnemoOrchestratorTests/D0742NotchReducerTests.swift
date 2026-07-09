import XCTest
@testable import MnemoOrchestrator

/// D-0742: concurrency stress under WorkScheduler for NotchReducer (seed 2dae601f17d6).
final class D0742NotchReducerTests: XCTestCase {
    private let seed = "2dae601f17d6"

    func testConcurrency_stressSafe() {
        XCTAssertTrue(NotchReducer.concurrencyStressSafe())
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
                group.addTask { NotchReducer.concurrencyStressSafe() }
            }
            for await ok in group { XCTAssertTrue(ok) }
        }
    }
}
