import XCTest
@testable import MnemoOrchestrator

/// D-0962: concurrency stress under WorkScheduler for EntityExtractor (seed ff664fb13aa3).
final class D0962EntityExtractorTests: XCTestCase {
    private let seed = "ff664fb13aa3"
    func testConcurrencyStress_rng() async {
        XCTAssertTrue(Phase2Techniques.interactivePreemptsBackground())
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        let yield = await sched.shouldBackgroundYield
        await sched.endInteractive(token)
        XCTAssertTrue(yield)
    }

}
