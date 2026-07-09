import XCTest
@testable import MnemoOrchestrator

/// D-0002: Router concurrency stress under WorkScheduler (seed a27199799d0b).
final class D0002RouterConcurrencyTests: XCTestCase {
    private let seed = "a27199799d0b"

    func testConcurrentClassifyUnderSchedulerStress() async {
        let scheduler = WorkScheduler()
        let router = HeuristicRouter()
        var rng = Phase2RNG(seed: seed)

        await withTaskGroup(of: Intent.self) { group in
            for _ in 0..<32 {
                let q = rng.randomQuery(length: 3 + rng.nextInt(upperBound: 6))
                group.addTask {
                    await scheduler.runInteractive {
                        router.classify(q).intent
                    }
                }
            }
            var intents = Set<Intent>()
            for await intent in group { intents.insert(intent) }
            XCTAssertFalse(intents.isEmpty)
        }
    }

    func testSchedulerTokenIdentityPreventsDoubleEnd() async {
        let scheduler = WorkScheduler()
        let t1 = await scheduler.beginInteractive()
        let t2 = await scheduler.beginInteractive()
        XCTAssertTrue(await scheduler.shouldBackgroundYield)
        await scheduler.endInteractive(t1)
        XCTAssertTrue(await scheduler.shouldBackgroundYield, "second token still active")
        await scheduler.endInteractive(t2)
        XCTAssertFalse(await scheduler.shouldBackgroundYield)
        await scheduler.endInteractive(t1)
        XCTAssertFalse(await scheduler.shouldBackgroundYield, "stale token must not underflow")
    }

    func testLongLookupQueryRoutesAsLookup() {
        let router = HeuristicRouter()
        let q = "what is the name of the primary build tool used in the monorepo today"
        XCTAssertEqual(router.classify(q).intent, .lookup)
    }

    func testBackgroundYieldDuringInteractive() async {
        let scheduler = WorkScheduler()
        let token = await scheduler.beginInteractive()
        var completed = 0
        await scheduler.runBackgroundChunked(total: 100) { _ in completed += 1 }
        XCTAssertEqual(completed, 0, "background must yield while interactive active")
        await scheduler.endInteractive(token)
        await scheduler.runBackgroundChunked(total: 5) { _ in completed += 1 }
        XCTAssertEqual(completed, 5)
    }
}
