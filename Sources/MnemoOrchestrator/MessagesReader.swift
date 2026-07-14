import Foundation

/// One conversation reconstructed from the Messages database, ready to ingest.
public struct MessageConversation: Equatable, Sendable {
    public let chatGuid: String
    public let displayName: String?
    public let participants: [String]
    public let maxRowId: Int64
    public let messageCount: Int
    public let transcript: String
}

public enum MessagesReaderError: Error, Equatable, Sendable {
    case sqlite(status: Int32, message: String)
}

/// Reads the local Messages database (`~/Library/Messages/chat.db`) READ-ONLY and
/// reconstructs per-conversation transcripts. Shells to the system `sqlite3` CLI in
/// read-only + JSON mode — matching how this codebase already shells to `textutil`
/// and `grep` — so there is no new dependency, the live database is never locked or
/// mutated, and reading requires only Full Disk Access. Everything stays on device;
/// nothing egresses. (M16)
public struct MessagesReader: Sendable {
    /// Default location of the user's Messages database.
    public static var defaultDatabasePath: String {
        (NSHomeDirectory() as NSString).appendingPathComponent("Library/Messages/chat.db")
    }

    private let sqlite3Path: String

    public init(sqlite3Path: String = "/usr/bin/sqlite3") {
        self.sqlite3Path = sqlite3Path
    }

    struct Row: Decodable {
        let chat_guid: String
        let display_name: String?
        let row_id: Int64
        let text: String?
        let is_from_me: Int
        let handle: String?
    }

    // Ordered by chat then message time so transcripts read top-to-bottom and each
    // conversation's rows are contiguous.
    private static let query = """
        SELECT c.guid AS chat_guid, c.display_name AS display_name, \
        m.ROWID AS row_id, m.text AS text, m.is_from_me AS is_from_me, h.id AS handle \
        FROM chat c \
        JOIN chat_message_join cmj ON cmj.chat_id = c.ROWID \
        JOIN message m ON m.ROWID = cmj.message_id \
        LEFT JOIN handle h ON h.ROWID = m.handle_id \
        ORDER BY c.guid, m.date, m.ROWID;
        """

    /// Every conversation in the database, in stable order. Messages whose text is
    /// stored only in `attributedBody` (null `text`) are skipped from the transcript
    /// for now — decoding that typedstream blob is a follow-up — but their ROWID
    /// still advances the incremental cursor.
    public func read(databasePath: String) throws -> [MessageConversation] {
        let rows = try runJSON(databasePath: databasePath, sql: Self.query, as: [Row].self)
        return Self.group(rows)
    }

    static func group(_ rows: [Row]) -> [MessageConversation] {
        var order: [String] = []
        var byChat: [String: [Row]] = [:]
        for row in rows {
            if byChat[row.chat_guid] == nil { order.append(row.chat_guid) }
            byChat[row.chat_guid, default: []].append(row)
        }
        return order.map { guid in
            let chatRows = byChat[guid] ?? []
            let participants = Set(chatRows.compactMap(\.handle)).sorted()
            let maxRowId = chatRows.map(\.row_id).max() ?? 0
            let lines: [String] = chatRows.compactMap { row in
                guard let text = row.text, !text.isEmpty else { return nil }
                let sender = row.is_from_me == 1 ? "Me" : (row.handle ?? "Unknown")
                return "\(sender): \(text)"
            }
            let displayName = chatRows.first?.display_name.flatMap { $0.isEmpty ? nil : $0 }
            return MessageConversation(
                chatGuid: guid,
                displayName: displayName,
                participants: participants,
                maxRowId: maxRowId,
                messageCount: lines.count,
                transcript: lines.joined(separator: "\n")
            )
        }
    }

    private func runJSON<T: Decodable>(databasePath: String, sql: String, as _: T.Type) throws -> T {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sqlite3Path)
        process.arguments = ["-readonly", databasePath, "-cmd", ".mode json", sql]
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw MessagesReaderError.sqlite(
                status: process.terminationStatus,
                message: String(data: errData, encoding: .utf8) ?? "")
        }
        // sqlite3 emits nothing for an empty result set; normalize to an empty array.
        let text = (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonData = text.isEmpty ? Data("[]".utf8) : Data(text.utf8)
        return try JSONDecoder().decode(T.self, from: jsonData)
    }
}
