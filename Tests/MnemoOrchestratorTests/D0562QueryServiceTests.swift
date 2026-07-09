import XCTest
@testable import MnemoOrchestrator

/// D-0562: concurrency stress under WorkScheduler for QueryService (seed ae7918dce66c).
final class D0562QueryServiceTests: XCTestCase {
    private let seed = "ae7918dce66c"

    func testConcurrency_stressSafe() {
        XCTAssertTrue(QueryService.concurrencyStressSafe())
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
                group.addTask { QueryService.concurrencyStressSafe() }
            }
            for await ok in group { XCTAssertTrue(ok) }
        }
    }
}
