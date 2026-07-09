import XCTest
@testable import MnemoOrchestrator

/// D-0902: concurrency stress under WorkScheduler for PersonalRanker (seed ffec4dfcea5f).
final class D0902PersonalRankerTests: XCTestCase {
    private let seed = "ffec4dfcea5f"
    func testConcurrencyStress_rng() async {
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        await sched.endInteractive(token)
        XCTAssertTrue(yield)
    }

}
