import XCTest
@testable import MnemoOrchestrator

/// D-0842: concurrency stress under WorkScheduler for EgressGuard (seed f85699101bd8).
final class D0842EgressGuardTests: XCTestCase {
    private let seed = "f85699101bd8"
    func testConcurrencyStress_rng() async {
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        await sched.endInteractive(token)
        XCTAssertTrue(yield)
    }

}
