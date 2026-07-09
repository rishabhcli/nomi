import XCTest
@testable import MnemoOrchestrator

/// D-0984: offline refusal paths for OllamaClient (seed 7adc6406d1e4).
final class D0984OllamaClientTests: XCTestCase {
    private let seed = "7adc6406d1e4"
    func testOfflineRefusal_rng() {
        XCTAssertTrue(Phase2Techniques.offlineRefusalRenderable())
        XCTAssertFalse(QueryService.offlineRefusalEvents().isEmpty)
    }

}
