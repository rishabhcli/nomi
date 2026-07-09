import XCTest
@testable import MnemoOrchestrator

/// D-0722: concurrency stress under WorkScheduler for SpanResolver (seed ba351a03148d).
final class D0722SpanResolverTests: XCTestCase {
    private let seed = "ba351a03148d"

    func testConcurrency_stressSafe() {
        XCTAssertTrue(SpanResolver.concurrencyStressSafe())
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
                group.addTask { SpanResolver.concurrencyStressSafe() }
            }
            for await ok in group { XCTAssertTrue(ok) }
        }
    }
}
