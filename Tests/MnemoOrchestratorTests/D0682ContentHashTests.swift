import XCTest
@testable import MnemoOrchestrator

/// D-0682: concurrency stress under WorkScheduler for ContentHash (seed 40311bbc89cc).
final class D0682ContentHashTests: XCTestCase {
    private let seed = "40311bbc89cc"

    func testConcurrency_stressSafe() {
        XCTAssertTrue(ContentHash.concurrencyStressSafe())
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
                group.addTask { ContentHash.concurrencyStressSafe() }
            }
            for await ok in group { XCTAssertTrue(ok) }
        }
    }
}
