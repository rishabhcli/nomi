import XCTest
@testable import MnemoOrchestrator

/// D-0720: mnemoctl JSON schema stability for EngineIntegration (seed b24d8eb8aa43).
final class D0720EngineIntegrationTests: XCTestCase {
    private let seed = "b24d8eb8aa43"

    func testJSON_exportStable() throws {
        let data = try EngineIntegration.jsonExportData()
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
