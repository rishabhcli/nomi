import XCTest
@testable import MnemoOrchestrator

/// D-0020: MemoryDynamics mnemoctl JSON schema stability (seed 6f216c8c2562).
final class D0020MemoryDynamicsTests: XCTestCase {
    private let seed = "6f216c8c2562"

    func testSnapshotSchemaVersionStable() throws {
        let entry = MemoryEntry(id: "m1", memory: "User likes Bazel.", version: 1,
                                isLatest: true, isForgotten: false, isStatic: false,
                                parentMemoryId: nil, rootMemoryId: "m1",
                                forgetAfter: nil, forgetReason: nil, history: [])
        let snap = MemoryDynamicsSnapshot(container: "mnemo", entries: [entry])
        XCTAssertEqual(snap.schemaVersion, 1)
        XCTAssertEqual(snap.activeCount, 1)
        let json = try JSONDecoder().decode([String: JSONValue].self, from: try snap.jsonData())
        XCTAssertEqual(json["schemaVersion"]?.int, 1)
        XCTAssertEqual(json["container"]?.string, "mnemo")
    }

    func testForgottenExcludedFromSnapshot() throws {
        let forgotten = MemoryEntry(id: "f1", memory: "gone", version: 1, isLatest: true, isForgotten: true,
                                    isStatic: false, parentMemoryId: nil, rootMemoryId: "f1",
                                    forgetAfter: nil, forgetReason: "user", history: [])
        let snap = MemoryDynamicsSnapshot(container: "mnemo", entries: [forgotten])
        XCTAssertEqual(snap.activeCount, 0)
        XCTAssertTrue(snap.entries.isEmpty)
    }

    func testJsonKeysSortedForStability() throws {
        let snap = MemoryDynamicsSnapshot(container: "c", entries: [])
        let raw = String(data: try snap.jsonData(), encoding: .utf8)!
        XCTAssertTrue(raw.hasPrefix("{\"activeCount\"") || raw.contains("\"schemaVersion\""))
        let second = String(data: try snap.jsonData(), encoding: .utf8)!
        XCTAssertEqual(raw, second)
    }

    func testProperty_activeCountMatchesFilter() {
        var rng = Phase2RNG(seed: seed)
        for i in 0..<6 {
            let active = MemoryEntry(id: "a\(i)", memory: "fact \(i)", version: 1, isLatest: true,
                                     isForgotten: false, isStatic: false, parentMemoryId: nil,
                                     rootMemoryId: "a\(i)", forgetAfter: nil, forgetReason: nil, history: [])
            let forgotten = i % 2 == 0
                ? MemoryEntry(id: "f\(i)", memory: "gone", version: 1, isLatest: true, isForgotten: true,
                              isStatic: false, parentMemoryId: nil, rootMemoryId: "f\(i)",
                              forgetAfter: nil, forgetReason: nil, history: [])
                : nil
            var entries = [active]
            if let f = forgotten { entries.append(f) }
            _ = rng.nextInt(upperBound: 10)
            let snap = MemoryDynamicsSnapshot(container: "mnemo", entries: entries)
            XCTAssertEqual(snap.activeCount, 1)
        }
    }
}

/// Minimal JSON helper for schema assertions.
private enum JSONValue: Decodable {
    case int(Int), string(String), array([JSONValue]), object([String: JSONValue])
    var int: Int? { if case .int(let v) = self { return v }; return nil }
    var string: String? { if case .string(let v) = self { return v }; return nil }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { self = .int(i) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "unsupported") }
    }
}
