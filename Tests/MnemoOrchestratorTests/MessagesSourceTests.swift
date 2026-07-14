import XCTest
@testable import MnemoOrchestrator

private actor RecordingCreator: DocumentCreating {
    struct Call: Sendable {
        let content: String
        let customId: String?
        let container: String?
        let metadata: [String: String]
    }
    var calls: [Call] = []
    func createDocument(content: String, customId: String?, container: String?,
                        metadata: [String: String]) async throws -> String {
        calls.append(.init(content: content, customId: customId, container: container, metadata: metadata))
        return "doc-\(calls.count)"
    }
}

/// M16: Messages conversations ingested into the `messages` container with source
/// provenance, and re-syncs of unchanged conversations are a no-op.
final class MessagesSourceTests: XCTestCase {

    private func makeFixtureDB() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "msgsrc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let db = dir.appending(path: "chat.db")
        let sql = """
        CREATE TABLE handle(ROWID INTEGER PRIMARY KEY, id TEXT);
        INSERT INTO handle VALUES (1,'+15551234567'),(2,'friend@example.com');
        CREATE TABLE chat(ROWID INTEGER PRIMARY KEY, guid TEXT, display_name TEXT);
        INSERT INTO chat VALUES (1,'iMessage;-;+15551234567',''),(2,'iMessage;-;group','Team');
        CREATE TABLE message(ROWID INTEGER PRIMARY KEY, text TEXT, is_from_me INTEGER, date INTEGER, handle_id INTEGER);
        INSERT INTO message VALUES
          (1,'Hey, launch is Friday',0,1000,1),
          (2,'Got it, thanks',1,1001,NULL),
          (3,'Standup at 10',0,2000,2);
        CREATE TABLE chat_message_join(chat_id INTEGER, message_id INTEGER);
        INSERT INTO chat_message_join VALUES (1,1),(1,2),(2,3);
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        p.arguments = [db.path, sql]
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw NSError(domain: "fixture", code: Int(p.terminationStatus)) }
        return db
    }

    func testIngestsConversationsIntoMessagesContainerWithProvenance() async throws {
        let db = try makeFixtureDB()
        defer { try? FileManager.default.removeItem(at: db.deletingLastPathComponent()) }
        let creator = RecordingCreator()
        let cpURL = db.deletingLastPathComponent().appending(path: "cp.json")
        let source = MessagesSource(databasePath: db.path, creator: creator,
                                    checkpoint: SourceCheckpoint(url: cpURL))

        let report = try await source.sync(limit: 100)

        XCTAssertEqual(report.kind, .messages)
        XCTAssertEqual(report.container, "messages")
        XCTAssertEqual(report.uploaded, 2)

        let calls = await creator.calls
        XCTAssertEqual(calls.count, 2)
        XCTAssertTrue(calls.allSatisfy { $0.container == "messages" })
        XCTAssertEqual(calls[0].customId, "mnemo-imessage-iMessage;-;+15551234567")
        XCTAssertEqual(calls[0].metadata[SourceProvenance.sourceKindKey], "messages")
        XCTAssertEqual(calls[0].metadata[MediaCompanion.originalPathKey], "messages://iMessage;-;+15551234567")
        XCTAssertTrue(calls[0].content.contains("Hey, launch is Friday"), calls[0].content)
    }

    func testUnchangedConversationsSkippedOnResync() async throws {
        let db = try makeFixtureDB()
        defer { try? FileManager.default.removeItem(at: db.deletingLastPathComponent()) }
        let creator = RecordingCreator()
        let cpURL = db.deletingLastPathComponent().appending(path: "cp.json")
        let source = MessagesSource(databasePath: db.path, creator: creator,
                                    checkpoint: SourceCheckpoint(url: cpURL))

        _ = try await source.sync(limit: 100)
        let second = try await source.sync(limit: 100)

        XCTAssertEqual(second.unchanged, 2)
        XCTAssertEqual(second.uploaded, 0)
        let calls = await creator.calls
        XCTAssertEqual(calls.count, 2, "re-sync of unchanged conversations must not re-ingest")
    }
}
