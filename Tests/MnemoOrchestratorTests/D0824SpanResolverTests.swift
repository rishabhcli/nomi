import XCTest
@testable import MnemoOrchestrator

/// D-0824: offline refusal paths for SpanResolver (seed 2fb6ec3ed345).
final class D0824SpanResolverTests: XCTestCase {
    private let seed = "2fb6ec3ed345"
    func testOfflineRefusal_rng() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
        XCTAssertFalse(QueryService.offlineRefusalEvents().isEmpty)
    }

}
