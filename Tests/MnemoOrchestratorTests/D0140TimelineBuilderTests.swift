import XCTest
@testable import MnemoOrchestrator

/// D-0140: TimelineBuilder mnemoctl JSON schema stability (seed 8f2969b037fe).
final class D0140TimelineBuilderTests: XCTestCase {
    private let seed = "8f2969b037fe"

    func testJsonSchemaStable() throws {
        let data = try TimelineBuilder.jsonExportData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
    }
}
