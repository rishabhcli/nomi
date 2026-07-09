import XCTest
@testable import MnemoOrchestrator

/// D-0180: WorkScheduler mnemoctl JSON schema stability (seed 74555d5f0780).
final class D0180WorkSchedulerTests: XCTestCase {
    private let seed = "74555d5f0780"

    func testJsonSchemaStable() throws {
        let data = try WorkScheduler.jsonExportData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
    }
}
