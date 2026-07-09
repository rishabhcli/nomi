import XCTest
@testable import MnemoOrchestrator

/// D-0700: mnemoctl JSON schema stability for TimeWindow (seed 36f49510f641).
final class D0700TimeWindowTests: XCTestCase {
    private let seed = "36f49510f641"

    func testJSON_exportStable() throws {
        let data = try TimeWindow.jsonExportData()
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
