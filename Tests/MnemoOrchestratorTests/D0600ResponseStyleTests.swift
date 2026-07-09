import XCTest
@testable import MnemoOrchestrator

/// D-0600: mnemoctl JSON schema stability for ResponseStyle (seed ffeee0c068e4).
final class D0600ResponseStyleTests: XCTestCase {
    private let seed = "ffeee0c068e4"

    func testJSON_exportStable() throws {
        let data = try ResponseStyle.jsonExportData()
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
