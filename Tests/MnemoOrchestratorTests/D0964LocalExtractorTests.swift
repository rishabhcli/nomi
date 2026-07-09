import XCTest
@testable import MnemoOrchestrator

/// D-0964: offline refusal paths for LocalExtractor (seed 3a47ac278542).
final class D0964LocalExtractorTests: XCTestCase {
    private let seed = "3a47ac278542"
    func testOfflineRefusal_rng() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
        XCTAssertFalse(QueryService.offlineRefusalEvents().isEmpty)
    }

}
