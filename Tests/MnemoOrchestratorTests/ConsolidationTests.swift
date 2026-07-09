import XCTest
@testable import MnemoOrchestrator

final class StrengthLedgerTests: XCTestCase {
    func tempPath() -> String {
        FileManager.default.temporaryDirectory.appending(path: "mnemo-strength-\(UUID()).json").path
    }

    func testStrengthenIncrementsAndPersists() async throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let ledger = StrengthLedger(path: path)
        await ledger.strengthen("m1", at: Date(timeIntervalSince1970: 100))
        await ledger.strengthen("m1", at: Date(timeIntervalSince1970: 200))
        let rec = await ledger.record("m1")
        XCTAssertEqual(rec?.retrievalCount, 2)
        XCTAssertEqual(rec?.lastRetrieved.timeIntervalSince1970, 200)

        // A fresh ledger on the same path sees the persisted state.
        let reopened = StrengthLedger(path: path)
        let reloaded = await reopened.record("m1")
        XCTAssertEqual(reloaded?.retrievalCount, 2)
    }

    func testStrengthenedRanksHigher() async {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let ledger = StrengthLedger(path: path)
        await ledger.strengthen("hot", at: Date())
        await ledger.strengthen("hot", at: Date())
        await ledger.strengthen("cold", at: Date())
        let ranked = await ledger.rankByStrength(["cold", "hot"])
        XCTAssertEqual(ranked, ["hot", "cold"])
    }
}

final class ColdArchivePolicyTests: XCTestCase {
    func testArchivesMemoriesUntouchedPastThreshold() {
        let now = Date(timeIntervalSince1970: 100 * 86400)
        let records: [String: StrengthRecord] = [
            "fresh": StrengthRecord(retrievalCount: 3, lastRetrieved: now.addingTimeInterval(-5 * 86400)),
            "stale": StrengthRecord(retrievalCount: 1, lastRetrieved: now.addingTimeInterval(-40 * 86400)),
        ]
        let archivable = ColdArchive.archivable(records: records, now: now, thresholdDays: 30)
        XCTAssertEqual(archivable, ["stale"])
    }
}

final class PromotionPolicyTests: XCTestCase {
    func testRecurringDynamicFactPromotable() {
        let counts = ["recurring": 4, "rare": 1]
        let ids = Promotion.promotable(retrievalCounts: counts, minAssertions: 3)
        XCTAssertEqual(ids, ["recurring"])
    }
}

// MARK: - Consolidator orchestration

actor DreamFakeStore: MemoryStoring {
    var entries: [MemoryEntry]
    var created: [(content: String, isStatic: Bool)] = []
    var forgotten: [String] = []
    init(_ e: [MemoryEntry]) { entries = e }
    func createMemory(content: String, isStatic: Bool, forgetAfter: String?, container: String?) async throws -> String {
        created.append((content, isStatic)); return "new-\(created.count)"
    }
    func supersedeMemory(id: String, newContent: String, container: String?) async throws -> String { id }
    func forgetMemory(id: String, reason: String, container: String?) async throws { forgotten.append(id) }
    func listMemories(container: String?) async throws -> [MemoryEntry] { entries }
}

struct StubSynthesizer: PatternSynthesizing {
    let output: String?
    func synthesize(_ cluster: [MemoryEntry]) async -> String? { output }
}

private func dmem(_ id: String, _ text: String, isStatic: Bool = false) -> MemoryEntry {
    MemoryEntry(id: id, memory: text, version: 1, isLatest: true, isForgotten: false,
                isStatic: isStatic, parentMemoryId: nil, rootMemoryId: id,
                forgetAfter: nil, forgetReason: nil, history: [], documentIds: ["d"])
}

final class ConsolidatorTests: XCTestCase {
    func tempPath() -> String { FileManager.default.temporaryDirectory.appending(path: "mnemo-str-\(UUID()).json").path }

    func testDreamPromotesRecurringDynamicToStatic() async throws {
        let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
        let store = DreamFakeStore([dmem("m1", "I prefer dark roast coffee.")])
        let ledger = StrengthLedger(path: path)
        for _ in 0..<3 { await ledger.strengthen("m1", at: Date()) }
        let c = Consolidator(store: store, ledger: ledger, container: "mnemo",
                             synthesizer: StubSynthesizer(output: nil),
                             coldThresholdDays: 30, promoteMinAssertions: 3)
        try await c.dream(now: Date())
        let created = await store.created
        XCTAssertTrue(created.contains { $0.content == "I prefer dark roast coffee." && $0.isStatic })
        let forgotten = await store.forgotten
        XCTAssertTrue(forgotten.contains("m1"), "the dynamic original is retired after promotion")
    }

    func testDreamSynthesizesClusterCitingConstituents() async throws {
        let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
        let store = DreamFakeStore([
            dmem("m1", "I use Bazel for the renderer."),
            dmem("m2", "I use Bazel for the server."),
            dmem("m3", "I migrated the mobile app to Bazel."),
        ])
        let c = Consolidator(store: store, ledger: StrengthLedger(path: path), container: "mnemo",
                             synthesizer: StubSynthesizer(output: "The user standardizes on Bazel across all projects."),
                             coldThresholdDays: 30, promoteMinAssertions: 99)   // no promotion
        try await c.dream(now: Date())
        let created = await store.created
        XCTAssertTrue(created.contains { $0.content.contains("standardizes on Bazel") })
    }

    func testDreamArchivesColdMemories() async throws {
        let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
        let store = DreamFakeStore([dmem("cold", "An old ephemeral note.")])
        let ledger = StrengthLedger(path: path)
        await ledger.strengthen("cold", at: Date(timeIntervalSince1970: 0))   // touched long ago
        let c = Consolidator(store: store, ledger: ledger, container: "mnemo",
                             synthesizer: StubSynthesizer(output: nil),
                             coldThresholdDays: 30, promoteMinAssertions: 3)
        try await c.dream(now: Date(timeIntervalSince1970: 100 * 86400))
        let forgotten = await store.forgotten
        XCTAssertTrue(forgotten.contains("cold"))
    }
}
