import XCTest
@testable import MnemoOrchestrator

/// D-0702: concurrency stress under WorkScheduler for ResponseStyle (seed be627802f367).
final class D0702ResponseStyleTests: XCTestCase {
    private let seed = "be627802f367"

    func testConcurrency_stressSafe() {
        XCTAssertTrue(ResponseStyle.concurrencyStressSafe())
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
    }

    func testConcurrency_schedulingYield() async {
        let scheduler = WorkScheduler()
        let token = await scheduler.beginInteractive()
        await ResponseStyle.Scheduling.yieldIfInteractiveWaiting(scheduler)
        await scheduler.endInteractive(token)
    }

    func testConcurrency_parallelLifecycle() async {
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<6 {
                group.addTask { ResponseStyle.concurrencyStressSafe() }
            }
            for await ok in group { XCTAssertTrue(ok) }
        }
    }
}
