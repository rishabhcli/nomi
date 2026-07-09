import XCTest
@testable import MnemoOrchestrator

/// D-0282: WorkScheduler concurrency stress under WorkScheduler (seed 34b20b6ca0c6).
final class D0282WorkSchedulerTests: XCTestCase {
    private let seed = "34b20b6ca0c6"

    func testInteractivePreemptsBackground() async {
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        XCTAssertTrue(yield)
        await sched.endInteractive(token)
        let after = await sched.shouldBackgroundYield
        XCTAssertFalse(after)
    }

    func testSchedulingYieldHintInteractive() {
        XCTAssertFalse(WorkScheduler.schedulingYieldHint(priority: .interactive))
    }

    func testProperty_tokenLifecycle() async {
        var rng = Phase2RNG(seed: seed)
        let sched = WorkScheduler()
        var tokens: [WorkScheduler.Token] = []
        for _ in 0..<(rng.nextInt(upperBound: 3) + 1) {
            tokens.append(await sched.beginInteractive())
        }
        for t in tokens { await sched.endInteractive(t) }
        XCTAssertFalse(await sched.shouldBackgroundYield)
    }
}
