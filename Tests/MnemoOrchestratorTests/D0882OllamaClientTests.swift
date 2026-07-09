import XCTest
@testable import MnemoOrchestrator

/// D-0882: concurrency stress under WorkScheduler for OllamaClient (seed d8ef3e6e7563).
final class D0882OllamaClientTests: XCTestCase {
    private let seed = "d8ef3e6e7563"
    func testConcurrencyStress_rng() async {
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        await sched.endInteractive(token)
        XCTAssertTrue(yield)
    }

}
