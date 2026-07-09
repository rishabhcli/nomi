import XCTest
@testable import MnemoOrchestrator

private func memEntry(_ id: String, docIds: [String], forgotten: Bool = false) -> MemoryEntry {
    MemoryEntry(id: id, memory: "m-\(id)", version: 1, isLatest: true, isForgotten: forgotten,
                isStatic: false, parentMemoryId: nil, rootMemoryId: id,
                forgetAfter: nil, forgetReason: nil, history: [], documentIds: docIds)
}

final class SelfHealTests: XCTestCase {
    func testFindsMemoriesWhoseSourcesAreAllGone() {
        let memories = [
            memEntry("m1", docIds: ["docA"]),          // docA alive → keep
            memEntry("m2", docIds: ["docGONE"]),       // orphan
            memEntry("m3", docIds: ["docGONE", "docA"]), // partly alive → keep
            memEntry("m4", docIds: []),                // no sources → orphan
        ]
        let orphans = SelfHeal.orphanedMemoryIds(memories: memories, liveDocIds: ["docA", "docB"])
        XCTAssertEqual(Set(orphans), ["m2", "m4"])
    }

    func testAlreadyForgottenAreNotReprocessed() {
        let memories = [memEntry("m1", docIds: ["gone"], forgotten: true)]
        XCTAssertTrue(SelfHeal.orphanedMemoryIds(memories: memories, liveDocIds: []).isEmpty)
    }
}

actor SyncFakeStore: MemoryStoring {
    var entries: [MemoryEntry]
    var forgotten: [String] = []
    init(_ e: [MemoryEntry]) { entries = e }
    func createMemory(content: String, isStatic: Bool, forgetAfter: String?, container: String?) async throws -> String { "x" }
    func supersedeMemory(id: String, newContent: String, container: String?) async throws -> String { id }
    func forgetMemory(id: String, reason: String, container: String?) async throws { forgotten.append(id) }
    func listMemories(container: String?) async throws -> [MemoryEntry] { entries }
}

actor SyncFakeDocs: DocumentIndexing {
    let docs: [DocumentMeta]
    init(_ d: [DocumentMeta]) { docs = d }
    func documentsList(container: String?) async throws -> [DocumentMeta] { docs }
}

struct SyncFakeForcer: SyncForcing {
    let recorder: ForceRecorder
    func forceSync() async throws { await recorder.mark() }
}
actor ForceRecorder { var calls = 0; func mark() { calls += 1 } }

final class SyncEngineTests: XCTestCase {
    private func doc(_ id: String) -> DocumentMeta {
        DocumentMeta(id: id, filepath: "/\(id).md", title: id, status: "done",
                     containerTags: ["mnemo"], summary: nil, updatedAt: nil)
    }

    func testSelfHealForgetsOnlyOrphans() async throws {
        let store = SyncFakeStore([
            memEntry("m1", docIds: ["liveDoc"]),
            memEntry("m2", docIds: ["deadDoc"]),
        ])
        let docs = SyncFakeDocs([doc("liveDoc")])
        let engine = SyncEngine(store: store, docs: docs, container: "mnemo",
                                forcer: SyncFakeForcer(recorder: ForceRecorder()))
        let healed = try await engine.selfHeal()
        XCTAssertEqual(healed, 1)
        let forgotten = await store.forgotten
        XCTAssertEqual(forgotten, ["m2"])
    }

    func testForceSyncDelegatesToForcer() async throws {
        let rec = ForceRecorder()
        let engine = SyncEngine(store: SyncFakeStore([]), docs: SyncFakeDocs([]),
                                container: "mnemo", forcer: SyncFakeForcer(recorder: rec))
        try await engine.forceSync()
        let calls = await rec.calls
        XCTAssertEqual(calls, 1)
    }

    func testSelfHealIdempotentSecondPassZero() async throws {
        let store = SyncFakeStore([memEntry("m1", docIds: ["live"])])
        let engine = SyncEngine(store: store, docs: SyncFakeDocs([doc("live")]),
                                container: "mnemo", forcer: SyncFakeForcer(recorder: ForceRecorder()))
        let first = try await engine.selfHeal()
        let second = try await engine.selfHeal()
        XCTAssertEqual(first, 0)
        XCTAssertEqual(second, 0)
    }
}
