import XCTest
@testable import MnemoOrchestrator

/// D-0040: FollowUp mnemoctl JSON schema stability (seed dc368bc4ce40).
final class D0040FollowUpTests: XCTestCase {
    private let seed = "dc368bc4ce40"

    func testJsonSchemaStable() throws {
        let data = try FollowUp.jsonExportData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
    }
}
