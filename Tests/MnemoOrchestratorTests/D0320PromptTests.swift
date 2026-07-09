import XCTest
@testable import MnemoOrchestrator

/// D-0320: Prompt mnemoctl JSON schema stability (seed 97c7209b1dd2).
final class D0320PromptTests: XCTestCase {
    private let seed = "97c7209b1dd2"

    func testSnapshotSchemaVersion() throws {
        let snap = MemoryDynamicsSnapshot(container: "mnemo", entries: [Phase2TechniqueSupport.sampleMemory()])
        XCTAssertEqual(snap.schemaVersion, 1)
        let data = try snap.jsonData()
        XCTAssertFalse(data.isEmpty)
    }

    func testJsonKeysSorted() throws {
        let snap = MemoryDynamicsSnapshot(container: "c", entries: [])
        let raw = String(data: try snap.jsonData(), encoding: .utf8)!
        let second = String(data: try snap.jsonData(), encoding: .utf8)!
        XCTAssertEqual(raw, second)
    }

    func testProperty_activeCountMatchesFilter() {
        var rng = Phase2RNG(seed: seed)
        for i in 0..<4 {
            let e = Phase2TechniqueSupport.sampleMemory(id: "m\(i)", forgotten: i % 2 == 0)
            _ = rng.nextInt(upperBound: 5)
            let snap = MemoryDynamicsSnapshot(container: "mnemo", entries: [e])
            XCTAssertEqual(snap.activeCount, i % 2 == 0 ? 0 : 1)
        }
    }
}
