import XCTest
@testable import MnemoOrchestrator

/// D-0200: Digest mnemoctl JSON schema stability (seed 73f739018097).
final class D0200DigestTests: XCTestCase {
    private let seed = "73f739018097"

    func testJsonSchemaStable() throws {
        let data = try Digest.jsonExportData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
    }
}
