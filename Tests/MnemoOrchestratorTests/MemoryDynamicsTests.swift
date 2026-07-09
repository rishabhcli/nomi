import XCTest
@testable import MnemoOrchestrator

/// Records engine memory mutations for assertions.
actor FakeMemoryStore: MemoryStoring {
    struct Created: Equatable { let content: String; let isStatic: Bool; let forgetAfter: String? }
    var created: [Created] = []
    var superseded: [(id: String, newContent: String)] = []
    var forgotten: [(id: String, reason: String)] = []
    var entries: [MemoryEntry]

    init(entries: [MemoryEntry] = []) { self.entries = entries }

    func createMemory(content: String, isStatic: Bool, forgetAfter: String?, container: String?) async throws -> String {
        created.append(Created(content: content, isStatic: isStatic, forgetAfter: forgetAfter))
        return "new-\(created.count)"
    }
    func supersedeMemory(id: String, newContent: String, container: String?) async throws -> String {
        superseded.append((id, newContent)); return "\(id)-v2"
    }
    func forgetMemory(id: String, reason: String, container: String?) async throws {
        forgotten.append((id, reason))
    }
    func listMemories(container: String?) async throws -> [MemoryEntry] { entries }
}

/// Scriptable contradiction detector.
struct StubContradiction: ContradictionDetecting {
    let map: [String: String]   // newFact → existing id it supersedes
    func supersededFact(byNew newFact: String, among candidates: [MemoryEntry]) async -> String? {
        map[newFact]
    }
}

private func entry(_ id: String, _ text: String, isStatic: Bool = false) -> MemoryEntry {
    MemoryEntry(id: id, memory: text, version: 1, isLatest: true, isForgotten: false,
                isStatic: isStatic, parentMemoryId: nil, rootMemoryId: id,
                forgetAfter: nil, forgetReason: nil, history: [])
}

final class LexicalContradictionTests: XCTestCase {
    let det = LexicalContradiction()

    func testSameSubjectPredicateDifferentObjectContradicts() async {
        let candidates = [entry("m1", "I live in New York City.")]
        let hit = await det.supersededFact(byNew: "I live in San Francisco.", among: candidates)
        XCTAssertEqual(hit, "m1")
    }

    func testDifferentPredicateDoesNotContradict() async {
        let candidates = [entry("m1", "I live in New York City.")]
        let hit = await det.supersededFact(byNew: "I work in Boston.", among: candidates)
        XCTAssertNil(hit)
    }

    func testSameFactIsNotAContradiction() async {
        let candidates = [entry("m1", "I live in New York City.")]
        let hit = await det.supersededFact(byNew: "I live in New York City.", among: candidates)
        XCTAssertNil(hit, "identical object is not a contradiction")
    }
}

final class MemoryDynamicsTests: XCTestCase {
    func testNewContradictingFactSupersedesInPlace() async throws {
        let store = FakeMemoryStore(entries: [entry("m1", "I live in New York City.")])
        let dyn = MemoryDynamics(store: store, container: "mnemo",
                                 detector: StubContradiction(map: ["I moved to San Francisco.": "m1"]))
        try await dyn.onNewFacts(["I moved to San Francisco."], from: "doc1")
        let superseded = await store.superseded
        let created = await store.created
        XCTAssertEqual(superseded.map(\.id), ["m1"])
        XCTAssertEqual(superseded.first?.newContent, "I moved to San Francisco.")
        XCTAssertTrue(created.isEmpty, "contradiction supersedes, never duplicates")
    }

    func testNovelFactIsCreated() async throws {
        let store = FakeMemoryStore(entries: [entry("m1", "I live in NYC.")])
        let dyn = MemoryDynamics(store: store, container: "mnemo",
                                 detector: StubContradiction(map: [:]))
        try await dyn.onNewFacts(["I have a dog named Rex."], from: "doc1")
        let created = await store.created
        XCTAssertEqual(created.map(\.content), ["I have a dog named Rex."])
        let superseded = await store.superseded
        XCTAssertTrue(superseded.isEmpty)
    }

    func testSoftDeletePassesReason() async throws {
        let store = FakeMemoryStore()
        let dyn = MemoryDynamics(store: store, container: "mnemo", detector: StubContradiction(map: [:]))
        try await dyn.softDelete("m9", reason: .userRetraction)
        let forgotten = await store.forgotten
        XCTAssertEqual(forgotten.first?.id, "m9")
        XCTAssertEqual(forgotten.first?.reason, "user retraction")
    }

    func testHistoryReturnsVersionChain() async throws {
        let v1 = MemoryVersion(memory: "I live in NYC.", version: 1)
        let latest = MemoryEntry(id: "m2", memory: "I moved to SF.", version: 2, isLatest: true,
                                 isForgotten: false, isStatic: false, parentMemoryId: "m1",
                                 rootMemoryId: "m1", forgetAfter: nil, forgetReason: nil, history: [v1])
        let store = FakeMemoryStore(entries: [latest])
        let dyn = MemoryDynamics(store: store, container: "mnemo", detector: StubContradiction(map: [:]))
        let hist = try await dyn.history(of: "m1")
        XCTAssertEqual(hist.map(\.memory), ["I moved to SF.", "I live in NYC."])
    }
}

final class MemoryEntryDecodeTests: XCTestCase {
    func testDecodesListEntry() throws {
        let json = """
        {"memoryEntries":[{"id":"m2","memory":"I moved to SF.","version":2,"isLatest":true,
          "isForgotten":false,"isStatic":false,"parentMemoryId":"m1","rootMemoryId":"m1",
          "forgetAfter":null,"forgetReason":null,
          "history":[{"memory":"I live in NYC.","version":1}]}],
         "pagination":{"currentPage":1,"totalPages":1}}
        """
        let page = try JSONDecoder().decode(EngineClient.MemoryListPage.self, from: Data(json.utf8))
        XCTAssertEqual(page.memoryEntries.count, 1)
        XCTAssertEqual(page.memoryEntries[0].version, 2)
        XCTAssertEqual(page.memoryEntries[0].history.first?.memory, "I live in NYC.")
    }
}
