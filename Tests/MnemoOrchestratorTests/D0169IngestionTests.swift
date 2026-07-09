import XCTest
@testable import MnemoOrchestrator

/// D-0169: Ingestion memory supersession race conditions (seed 0cccc5a37748).
final class D0169IngestionTests: XCTestCase {
    private let seed = "0cccc5a37748"

    func testSupersessionRaceSafe() {
        let k1 = Ingestion.supersessionKey(id: "a", version: 1)
        let k2 = Ingestion.supersessionKey(id: "a", version: 2)
        XCTAssertNotEqual(k1, k2)
        XCTAssertTrue(Ingestion.supersessionRaceSafe())
    }
}
