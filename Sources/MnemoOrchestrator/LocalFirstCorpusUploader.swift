import Foundation

public enum LocalFirstCorpusUploadError: Error, Equatable, Sendable {
    case unsupportedLocalType(String)
    case emptyExtraction(String)
}

/// Fail-closed file boundary for automatic volume ingestion. Media and rich
/// documents are converted to plain text on-device before the loopback engine
/// sees them, avoiding the engine build's hosted OCR fallbacks entirely.
public struct LocalFirstCorpusUploader: CorpusFileUploading {
    private static let directSafeExtensions: Set<String> = [
        "txt", "md", "markdown", "csv", "tsv", "json", "jsonl",
        "yaml", "yml", "toml", "xml", "html", "htm",
    ]

    private let directUploader: CorpusFileUploading
    private let creator: DocumentCreating
    private let scheduler: WorkScheduler?
    private let extract: @Sendable (URL) async throws -> String?

    public init(
        directUploader: CorpusFileUploading,
        creator: DocumentCreating,
        scheduler: WorkScheduler? = nil,
        extract: (@Sendable (URL) async throws -> String?)? = nil
    ) {
        self.directUploader = directUploader
        self.creator = creator
        self.scheduler = scheduler
        self.extract = extract ?? { url in
            try await LocalExtractor.extract(url, scheduler: scheduler)
        }
    }

    public func uploadFile(
        _ fileURL: URL,
        container: String?,
        metadata: [String: String]
    ) async throws -> String {
        try await waitForInteractiveWork()
        let ext = fileURL.pathExtension.lowercased()
        switch LocalExtractor.Kind(url: fileURL) {
        case .image, .pdf, .docx, .audioVideo:
            guard let text = try await extract(fileURL),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw LocalFirstCorpusUploadError.emptyExtraction(fileURL.path) }
            try await waitForInteractiveWork()

            var localMetadata = metadata
            localMetadata[MediaCompanion.extractionKey] = "on-device"
            localMetadata[ExternalCorpusMetadata.originalPath] =
                metadata[ExternalCorpusMetadata.originalPath] ?? fileURL.path
            let title = fileURL.lastPathComponent
            let content = "# \(title)\n\n\(text)"
            let identityPath = localMetadata[ExternalCorpusMetadata.originalPath] ?? fileURL.path
            let identity = ContentHash.sha256Hex(of: Data(identityPath.utf8))
            return try await creator.createDocument(
                content: content,
                customId: "mnemo-volume-\(identity)",
                container: container,
                metadata: localMetadata
            )
        case .unsupported:
            guard Self.directSafeExtensions.contains(ext) else {
                throw LocalFirstCorpusUploadError.unsupportedLocalType(ext)
            }
            try await waitForInteractiveWork()
            return try await directUploader.uploadFile(
                fileURL,
                container: container,
                metadata: metadata
            )
        }
    }

    private func waitForInteractiveWork() async throws {
        guard let scheduler else { return }
        while await scheduler.shouldBackgroundYield {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(100))
        }
    }
}
