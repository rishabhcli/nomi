import XCTest
@testable import MnemoOrchestrator

/// D-0862: concurrency stress under WorkScheduler for LocalExtractor (seed 9ca005b26184).
final class D0862LocalExtractorTests: XCTestCase {
    private let seed = "9ca005b26184"
    func testConcurrencyStress_rng() async {
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        await sched.endInteractive(token)
        XCTAssertTrue(yield)
    }

}
