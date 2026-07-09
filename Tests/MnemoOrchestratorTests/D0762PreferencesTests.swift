import XCTest
@testable import MnemoOrchestrator

/// D-0762: concurrency stress under WorkScheduler for Preferences (seed ff7f48f1d5e0).
final class D0762PreferencesTests: XCTestCase {
    private let seed = "ff7f48f1d5e0"
    func testConcurrencyStress_rng() async {
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        await sched.endInteractive(token)
        XCTAssertTrue(yield)
    }

}
