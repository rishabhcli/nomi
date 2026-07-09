import XCTest
@testable import MnemoOrchestrator

/// D-0560: mnemoctl JSON schema stability for Highlight (seed f275e87dcd4c).
final class D0560HighlightTests: XCTestCase {
    private let seed = "f275e87dcd4c"

    func testJSON_exportStable() throws {
        let data = try Highlight.jsonExportData()
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
