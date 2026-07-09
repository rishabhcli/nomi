import XCTest
@testable import MnemoOrchestrator

/// D-0220: Ingestion mnemoctl JSON schema stability (seed 840d3f939115).
final class D0220IngestionTests: XCTestCase {
    private let seed = "840d3f939115"

    func testJsonSchemaStable() throws {
        let data = try Ingestion.jsonExportData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
    }
}
