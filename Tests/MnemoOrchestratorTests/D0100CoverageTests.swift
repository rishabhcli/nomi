import XCTest
@testable import MnemoOrchestrator

/// D-0100: Coverage mnemoctl JSON schema stability (seed c296b1af7e07).
final class D0100CoverageTests: XCTestCase {
    private let seed = "c296b1af7e07"

    func testJsonSchemaStable() throws {
        let data = try Coverage.jsonExportData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
    }
}
