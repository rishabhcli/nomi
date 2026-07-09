import XCTest
@testable import MnemoOrchestrator

/// D-0942: concurrency stress under WorkScheduler for Inspector (seed 29021722928c).
final class D0942InspectorTests: XCTestCase {
    private let seed = "29021722928c"
    func testConcurrencyStress_rng() async {
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        await sched.endInteractive(token)
        XCTAssertTrue(yield)
    }

}
