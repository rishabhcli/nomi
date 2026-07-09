import XCTest
@testable import MnemoOrchestrator

/// D-0660: mnemoctl JSON schema stability for Preferences (seed 758975e455bc).
final class D0660PreferencesTests: XCTestCase {
    private let seed = "758975e455bc"

    func testJSON_exportStable() throws {
        let data = try Preferences.jsonExportData()
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["schemaVersion"] as? Int, 1)
    }

    func testJSON_scopeClassificationRoundTrip() throws {
        let sc = ScopeClassification(query: "what is bazel?", isCorpusQuestion: true, reply: nil)
        let back = try JSONDecoder().decode(ScopeClassification.self, from: sc.jsonData())
        XCTAssertEqual(back, sc)
    }

    func testJSON_schemaVersionConstant() {
        XCTAssertEqual(ScopeClassification.schemaVersion, Phase2Techniques.scopeSchemaVersion)
    }
}
