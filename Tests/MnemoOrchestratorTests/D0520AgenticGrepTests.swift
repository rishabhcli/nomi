import XCTest
@testable import MnemoOrchestrator

/// D-0520: mnemoctl JSON schema stability for AgenticGrep (seed f0dc2e729529).
final class D0520AgenticGrepTests: XCTestCase {
    private let seed = "f0dc2e729529"

    func testJSON_exportStable() throws {
        let data = try AgenticGrep.jsonExportData()
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
