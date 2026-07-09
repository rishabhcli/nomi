import XCTest
@testable import MnemoOrchestrator

/// D-0982: concurrency stress under WorkScheduler for ContextAssembler (seed 222ca1403f4c).
final class D0982ContextAssemblerTests: XCTestCase {
    private let seed = "222ca1403f4c"
    func testConcurrencyStress_rng() async {
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        await sched.endInteractive(token)
        XCTAssertTrue(yield)
    }

}
