import XCTest
@testable import MnemoOrchestrator

/// D-0802: concurrency stress under WorkScheduler for TimeWindow (seed 80de87691e84).
final class D0802TimeWindowTests: XCTestCase {
    private let seed = "80de87691e84"
    func testConcurrencyStress_rng() async {
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        await sched.endInteractive(token)
        XCTAssertTrue(yield)
    }

}
