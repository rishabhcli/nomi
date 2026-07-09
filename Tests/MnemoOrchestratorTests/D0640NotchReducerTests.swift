import XCTest
@testable import MnemoOrchestrator

/// D-0640: mnemoctl JSON schema stability for NotchReducer (seed ea20dbeb72a7).
final class D0640NotchReducerTests: XCTestCase {
    private let seed = "ea20dbeb72a7"

    func testJSON_exportStable() throws {
        let data = try NotchReducer.jsonExportData()
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
