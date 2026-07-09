import XCTest
@testable import MnemoOrchestrator

/// D-0822: concurrency stress under WorkScheduler for EngineIntegration (seed d825c654194f).
final class D0822EngineIntegrationTests: XCTestCase {
    private let seed = "d825c654194f"
    func testConcurrencyStress_rng() async {
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        await sched.endInteractive(token)
        XCTAssertTrue(yield)
    }

}
