import XCTest
@testable import MnemoOrchestrator

/// D-0080: QueryRewriter mnemoctl JSON schema stability (seed 8bcf6c3ac633).
final class D0080QueryRewriterTests: XCTestCase {
    private let seed = "8bcf6c3ac633"

    func testJsonSchemaStable() throws {
        let data = try QueryRewriter.jsonExportData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
    }
}
