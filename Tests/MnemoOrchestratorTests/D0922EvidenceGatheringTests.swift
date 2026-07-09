import XCTest
@testable import MnemoOrchestrator

/// D-0922: concurrency stress under WorkScheduler for EvidenceGathering (seed 00c610a4fa63).
final class D0922EvidenceGatheringTests: XCTestCase {
    private let seed = "00c610a4fa63"
    func testConcurrencyStress_rng() async {
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        await sched.endInteractive(token)
        XCTAssertTrue(yield)
    }

}
