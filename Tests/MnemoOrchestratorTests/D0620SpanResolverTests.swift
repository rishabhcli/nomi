import XCTest
@testable import MnemoOrchestrator

/// D-0620: mnemoctl JSON schema stability for SpanResolver (seed 97358f227909).
final class D0620SpanResolverTests: XCTestCase {
    private let seed = "97358f227909"

    func testJSON_exportStable() throws {
        let data = try SpanResolver.jsonExportData()
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
