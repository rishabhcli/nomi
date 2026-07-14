import XCTest
@testable import MnemoOrchestrator

/// M16: reconstruct per-conversation transcripts from the Messages database,
/// read-only, on-device. Built against a fixture chat.db so it runs offline in CI.
final class MessagesReaderTests: XCTestCase {

    /// Builds a minimal chat.db with the columns MessagesReader joins on.
    private func makeFixtureDB() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "msgdb-\(UUID().uuidString)")
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
          (3,'Standup at 10',0,2000,2),
          (4,NULL,0,2001,2);
        CREATE TABLE chat_message_join(chat_id INTEGER, message_id INTEGER);
        INSERT INTO chat_message_join VALUES (1,1),(1,2),(2,3),(2,4);
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        p.arguments = [db.path, sql]
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw NSError(domain: "fixture", code: Int(p.terminationStatus))
        }
        return db
    }

    func testReadsConversationsWithParticipantsAndTranscript() throws {
        let db = try makeFixtureDB()
        defer { try? FileManager.default.removeItem(at: db.deletingLastPathComponent()) }

        let convos = try MessagesReader().read(databasePath: db.path)

        XCTAssertEqual(convos.map(\.chatGuid),
                       ["iMessage;-;+15551234567", "iMessage;-;group"])

        let c1 = convos[0]
        XCTAssertEqual(c1.participants, ["+15551234567"])
        XCTAssertEqual(c1.messageCount, 2)
        XCTAssertEqual(c1.maxRowId, 2)
        XCTAssertTrue(c1.transcript.contains("Hey, launch is Friday"), c1.transcript)
        XCTAssertTrue(c1.transcript.contains("Me: Got it, thanks"), c1.transcript)

        let c2 = convos[1]
        XCTAssertEqual(c2.displayName, "Team")
        XCTAssertEqual(c2.participants, ["friend@example.com"])
        XCTAssertEqual(c2.messageCount, 1, "a null-text (attributedBody-only) message is skipped from the transcript")
        XCTAssertEqual(c2.maxRowId, 4, "but every message ROWID still advances the incremental cursor")
        XCTAssertTrue(c2.transcript.contains("Standup at 10"), c2.transcript)
    }
}
