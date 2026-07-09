import XCTest
@testable import MnemoOrchestrator

/// D-0580: mnemoctl JSON schema stability for ContentHash (seed 01131174f0c7).
final class D0580ContentHashTests: XCTestCase {
    private let seed = "01131174f0c7"

    func testJSON_exportStable() throws {
        let data = try ContentHash.jsonExportData()
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
