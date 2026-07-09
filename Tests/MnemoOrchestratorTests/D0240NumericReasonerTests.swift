import XCTest
@testable import MnemoOrchestrator

/// D-0240: NumericReasoner mnemoctl JSON schema stability (seed 5d7eff77f124).
final class D0240NumericReasonerTests: XCTestCase {
    private let seed = "5d7eff77f124"

    func testJsonSchemaStable() throws {
        let data = try NumericReasoner.jsonExportData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
    }
}
