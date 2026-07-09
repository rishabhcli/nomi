import XCTest
@testable import MnemoOrchestrator

/// D-0582: concurrency stress under WorkScheduler for ConflictDetector (seed dff32c1da267).
final class D0582ConflictDetectorTests: XCTestCase {
    private let seed = "dff32c1da267"

    func testConcurrency_stressSafe() {
        XCTAssertTrue(ConflictDetector.concurrencyStressSafe())
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
                group.addTask { ConflictDetector.concurrencyStressSafe() }
            }
            for await ok in group { XCTAssertTrue(ok) }
        }
    }
}
