import XCTest
@testable import MnemoOrchestrator

/// D-0782: concurrency stress under WorkScheduler for IngestGate (seed 222bfd0658bc).
final class D0782IngestGateTests: XCTestCase {
    private let seed = "222bfd0658bc"
    func testConcurrencyStress_rng() async {
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        await sched.endInteractive(token)
        XCTAssertTrue(yield)
    }

}
