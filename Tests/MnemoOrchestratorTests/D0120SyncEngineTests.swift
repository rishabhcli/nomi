import XCTest
@testable import MnemoOrchestrator

/// D-0120: SyncEngine mnemoctl JSON schema stability (seed 6494471139e6).
final class D0120SyncEngineTests: XCTestCase {
    private let seed = "6494471139e6"

    func testJsonSchemaStable() throws {
        let data = try SyncEngine.jsonExportData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
    }
}
