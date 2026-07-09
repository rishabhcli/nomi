import XCTest
@testable import MnemoOrchestrator

final class WorkSchedulerTests: XCTestCase {
    func testBackgroundYieldsWhileInteractiveInFlight() async {
        let sched = WorkScheduler()
        var yieldDuringInteractive = false
        let token = await sched.beginInteractive()
        yieldDuringInteractive = await sched.shouldBackgroundYield
        XCTAssertTrue(yieldDuringInteractive, "background must yield while an interactive query runs")
        await sched.endInteractive(token)
        let afterYield = await sched.shouldBackgroundYield
        XCTAssertFalse(afterYield, "no interactive in flight → background may run")
    }

    func testInteractivePriorityOverlaps() async {
        let sched = WorkScheduler()
        // Two interactive tasks in flight → both counted; yield stays true until both end.
        let t1 = await sched.beginInteractive()
        let t2 = await sched.beginInteractive()
        await sched.endInteractive(t1)
        let stillYield = await sched.shouldBackgroundYield
        XCTAssertTrue(stillYield, "still one interactive in flight")
        await sched.endInteractive(t2)
        let done = await sched.shouldBackgroundYield
        XCTAssertFalse(done)
    }

    func testRunInteractiveTracksLifecycle() async {
        let sched = WorkScheduler()
        let result = await sched.runInteractive { () -> Int in
            let yielding = await sched.shouldBackgroundYield
            XCTAssertTrue(yielding, "inside interactive work, background should yield")
            return 42
        }
        XCTAssertEqual(result, 42)
        let after = await sched.shouldBackgroundYield
        XCTAssertFalse(after)
    }

    func testChunkedBackgroundAbandonsWhenInteractiveArrives() async {
        let sched = WorkScheduler()
        let processed = Counter2()
        // Background processes 100 chunks but must stop early once interactive arrives.
        let bg = Task {
            await sched.runBackgroundChunked(total: 100) { i in
                await processed.set(i + 1)
                if i == 4 { let t = await sched.beginInteractive(); _ = t }  // interactive arrives at chunk 5
            }
        }
        await bg.value
        let done = await processed.value
        XCTAssertLessThan(done, 100, "background abandoned the remaining chunks for interactive")
        XCTAssertGreaterThanOrEqual(done, 5)
    }
}

actor Counter2 { var value = 0; func set(_ v: Int) { value = v } }
