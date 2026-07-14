import Foundation

/// The `messages` source: reconstructs iMessage/SMS conversations from the local
/// Messages database and ingests each as a document into the `messages` container,
/// stamped with source provenance and a stable locator, incrementally (an unchanged
/// conversation is skipped on re-sync). All on device via `MessagesReader` +
/// `DocumentCreating` — nothing egresses. Requires Full Disk Access at runtime. (M16)
public struct MessagesSource: IngestSource {
    public let kind: SourceKind = .messages

    private let databasePath: String
    private let reader: MessagesReader
    private let creator: DocumentCreating
    private let checkpoint: SourceCheckpoint

    public init(databasePath: String = MessagesReader.defaultDatabasePath,
                reader: MessagesReader = MessagesReader(),
                creator: DocumentCreating,
                checkpoint: SourceCheckpoint) {
        self.databasePath = databasePath
        self.reader = reader
        self.creator = creator
        self.checkpoint = checkpoint
    }

    @discardableResult
    public func sync(limit: Int) async throws -> IngestReport {
        let conversations = try reader.read(databasePath: databasePath)
        var uploaded = 0, unchanged = 0, deferred = 0, failures = 0

        for convo in conversations {
            // A conversation changes when a new message lands (max ROWID advances) or
            // its message count changes — either shifts the fingerprint.
            let fingerprint = "\(convo.maxRowId)|\(convo.messageCount)"
            if await checkpoint.isUnchanged(key: convo.chatGuid, fingerprint: fingerprint) {
                unchanged += 1
                continue
            }
            guard uploaded < max(0, limit) else { deferred += 1; continue }

            let title = convo.displayName ?? convo.participants.joined(separator: ", ")
            let heading = title.isEmpty ? convo.chatGuid : title
            let content = "# \(heading)\n\n\(convo.transcript)"

            var metadata = SourceProvenance.stamp(kind)
            metadata[MediaCompanion.originalPathKey] = "messages://\(convo.chatGuid)"
            if !convo.participants.isEmpty {
                metadata["mnemo_participants"] = convo.participants.joined(separator: ", ")
            }

            do {
                let id = try await creator.createDocument(
                    content: content,
                    customId: "mnemo-imessage-\(convo.chatGuid)",
                    container: container,
                    metadata: metadata)
                try await checkpoint.record(key: convo.chatGuid, fingerprint: fingerprint, documentId: id)
                uploaded += 1
            } catch {
                failures += 1
            }
        }

        return IngestReport(kind: kind, container: container,
                            uploaded: uploaded, unchanged: unchanged,
                            deferred: deferred, failures: failures)
    }
}
