import XCTest
@testable import MnemoOrchestrator

/// D-0160: CitationVerifier mnemoctl JSON schema stability (seed 190c9537b494).
final class D0160CitationVerifierTests: XCTestCase {
    private let seed = "190c9537b494"

    func testJsonSchemaStable() throws {
        let data = try CitationVerifier.jsonExportData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
    }
}
