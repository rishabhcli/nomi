import XCTest
@testable import MnemoOrchestrator

/// D-0060: CharSpan mnemoctl JSON schema stability (seed e983c479eec0).
final class D0060CharSpanTests: XCTestCase {
    private let seed = "e983c479eec0"

    func testJsonSchemaStable() throws {
        let data = try CharSpan.jsonExportData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
    }
}
