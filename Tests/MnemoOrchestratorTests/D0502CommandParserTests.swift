import XCTest
@testable import MnemoOrchestrator

/// D-0502: concurrency stress under WorkScheduler for CommandParser (seed 64488605bf92).
final class D0502CommandParserTests: XCTestCase {
    private let seed = "64488605bf92"

    func testConcurrency_stressSafe() {
        XCTAssertTrue(CommandParser.concurrencyStressSafe())
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
    }

    func testConcurrency_schedulingYield() async {
        let scheduler = WorkScheduler()
        let token = await scheduler.beginInteractive()
        await CommandParser.Scheduling.yieldIfInteractiveWaiting(scheduler)
        await scheduler.endInteractive(token)
    }

    func testConcurrency_parallelLifecycle() async {
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<6 {
                group.addTask { CommandParser.concurrencyStressSafe() }
            }
            for await ok in group { XCTAssertTrue(ok) }
        }
    }

    func testParse_slashCommands() {
        XCTAssertEqual(CommandParser.parse("/help"), .command(.help))
        XCTAssertEqual(CommandParser.parse("plain query"), .query("plain query"))
    }
}
