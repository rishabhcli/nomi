import XCTest
@testable import MnemoOrchestrator

/// D-0540: mnemoctl JSON schema stability for QueryDecomposer (seed 15b458c11ad3).
final class D0540QueryDecomposerTests: XCTestCase {
    private let seed = "15b458c11ad3"

    func testJSON_exportStable() throws {
        let data = try QueryDecomposer.jsonExportData()
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
