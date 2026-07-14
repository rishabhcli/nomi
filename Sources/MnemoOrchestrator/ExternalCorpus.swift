import Foundation

public enum ExternalCorpusMetadata {
    public static let originalPath = MediaCompanion.originalPathKey
    public static let relativePath = "mnemo_relative_path"
    public static let rootPath = "mnemo_source_root"
    public static let fingerprint = "mnemo_file_fingerprint"
}

public enum ExternalCorpusSkipReason: String, Codable, Sendable {
    case hidden
    case package
    case symbolicLink
    case unsupportedType
    case tooLarge
    case unreadable
}

public struct ExternalCorpusSkipped: Equatable, Sendable {
    public let path: String
    public let reason: ExternalCorpusSkipReason
}

public struct ExternalCorpusCandidate: Equatable, Sendable {
    public let url: URL
    public let relativePath: String
    public let byteCount: Int64
    public let modifiedAt: Date
    public let fingerprint: String
}

public struct ExternalCorpusScanReport: Equatable, Sendable {
    public let root: URL
    public let candidates: [ExternalCorpusCandidate]
    public let skipped: [ExternalCorpusSkipped]

    public func skippedCount(for reason: ExternalCorpusSkipReason) -> Int {
        skipped.lazy.filter { $0.reason == reason }.count
    }
}

public enum ExternalCorpusScanError: Error, Equatable, Sendable {
    case missing(String)
    case notDirectory(String)
    case unreadable(String)
    case enumerationFailed(String)
}

public struct ExternalCorpusPolicy: Equatable, Sendable {
    public static let defaultExtensions: Set<String> = [
        "txt", "md", "markdown", "rtf", "csv", "tsv", "json", "jsonl",
        "yaml", "yml", "toml", "xml", "html", "htm",
        "pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx",
        "pages", "numbers", "key",
        "png", "jpg", "jpeg", "heic", "tif", "tiff", "webp", "gif",
        "m4a", "mp3", "wav", "aac", "mp4", "mov",
    ]

    public let maxFileBytes: Int64
    public let supportedExtensions: Set<String>

    public init(maxFileBytes: Int64, supportedExtensions: Set<String> = Self.defaultExtensions) {
        self.maxFileBytes = maxFileBytes
        self.supportedExtensions = Set(supportedExtensions.map { $0.lowercased() })
    }
}

/// Produces a deterministic, bounded plan for a large local folder. It never
/// follows symlinks or descends into application/document packages.
public struct ExternalCorpusScanner: Sendable {
    public let policy: ExternalCorpusPolicy

    public init(policy: ExternalCorpusPolicy) {
        self.policy = policy
    }

    public func scan(root rawRoot: URL) throws -> ExternalCorpusScanReport {
        let fileManager = FileManager.default
        let root = rawRoot.standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory) else {
            throw ExternalCorpusScanError.missing(root.path)
        }
        guard isDirectory.boolValue else {
            throw ExternalCorpusScanError.notDirectory(root.path)
        }
        guard fileManager.isReadableFile(atPath: root.path) else {
            throw ExternalCorpusScanError.unreadable(root.path)
        }

        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .isRegularFileKey, .isPackageKey,
            .isSymbolicLinkKey, .isHiddenKey, .fileSizeKey,
            .contentModificationDateKey,
        ]
        var enumerationError: ExternalCorpusScanError?
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { url, _ in
                enumerationError = .enumerationFailed(url.path)
                return true
            }
        ) else {
            throw ExternalCorpusScanError.enumerationFailed(root.path)
        }

        var candidates: [ExternalCorpusCandidate] = []
        var skipped: [ExternalCorpusSkipped] = []
        while let url = enumerator.nextObject() as? URL {
            let resolvedURL = url.standardizedFileURL.resolvingSymlinksInPath()
            let relativePath = Self.relativePath(for: resolvedURL, root: root)
            let name = url.lastPathComponent
            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: keys)
            } catch {
                skipped.append(.init(path: relativePath, reason: .unreadable))
                continue
            }

            if values.isHidden == true || name.hasPrefix(".")
                || name.hasSuffix(".smfs-error.txt") {
                if values.isDirectory == true { enumerator.skipDescendants() }
                skipped.append(.init(path: relativePath, reason: .hidden))
                continue
            }
            if values.isPackage == true {
                enumerator.skipDescendants()
                skipped.append(.init(path: relativePath, reason: .package))
                continue
            }
            if values.isSymbolicLink == true {
                if values.isDirectory == true { enumerator.skipDescendants() }
                skipped.append(.init(path: relativePath, reason: .symbolicLink))
                continue
            }
            guard values.isRegularFile == true else { continue }

            let ext = url.pathExtension.lowercased()
            guard policy.supportedExtensions.contains(ext) else {
                skipped.append(.init(path: relativePath, reason: .unsupportedType))
                continue
            }
            guard fileManager.isReadableFile(atPath: url.path) else {
                skipped.append(.init(path: relativePath, reason: .unreadable))
                continue
            }
            let byteCount = Int64(values.fileSize ?? 0)
            guard byteCount <= policy.maxFileBytes else {
                skipped.append(.init(path: relativePath, reason: .tooLarge))
                continue
            }
            let modifiedAt = values.contentModificationDate ?? .distantPast
            candidates.append(.init(
                url: resolvedURL,
                relativePath: relativePath,
                byteCount: byteCount,
                modifiedAt: modifiedAt,
                fingerprint: Self.fingerprint(
                    relativePath: relativePath,
                    byteCount: byteCount,
                    modifiedAt: modifiedAt
                )
            ))
        }

        if candidates.isEmpty, let enumerationError { throw enumerationError }
        return ExternalCorpusScanReport(
            root: root,
            candidates: candidates.sorted { $0.relativePath < $1.relativePath },
            skipped: skipped.sorted { $0.path < $1.path }
        )
    }

    private static func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path.hasPrefix(rootPath) else { return url.lastPathComponent }
        return String(url.path.dropFirst(rootPath.count))
    }

    private static func fingerprint(
        relativePath: String,
        byteCount: Int64,
        modifiedAt: Date
    ) -> String {
        "\(relativePath)|\(byteCount)|\(modifiedAt.timeIntervalSinceReferenceDate.bitPattern)"
    }
}

public protocol CorpusFileUploading: Sendable {
    func uploadFile(
        _ fileURL: URL,
        container: String?,
        metadata: [String: String]
    ) async throws -> String
}

public struct ExternalCorpusUpload: Equatable, Codable, Sendable {
    public let path: String
    public let documentId: String
}

public struct ExternalCorpusFailure: Equatable, Sendable {
    public let path: String
    public let message: String
}

public struct ExternalCorpusIngestReport: Equatable, Sendable {
    public let scan: ExternalCorpusScanReport
    public let uploaded: [ExternalCorpusUpload]
    public let unchangedCount: Int
    public let deferredCount: Int
    public let failures: [ExternalCorpusFailure]
}

private struct ExternalCorpusCheckpoint: Codable {
    struct Entry: Codable {
        let fingerprint: String
        let documentId: String
    }
    var entries: [String: Entry] = [:]
}

/// Sequential uploader with a durable checkpoint. Sequential upload keeps a
/// multi-terabyte source from flooding the two-worker local engine.
public actor ExternalCorpusIngestor {
    private let uploader: CorpusFileUploading
    private let scanner: ExternalCorpusScanner
    private let checkpointURL: URL

    public init(
        uploader: CorpusFileUploading,
        scanner: ExternalCorpusScanner,
        checkpointURL: URL
    ) {
        self.uploader = uploader
        self.scanner = scanner
        self.checkpointURL = checkpointURL
    }

    public func ingest(
        root: URL,
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String] = [:]
    ) async throws -> ExternalCorpusIngestReport {
        let scan = try scanner.scan(root: root)
        var checkpoint = loadCheckpoint()
        var uploaded: [ExternalCorpusUpload] = []
        var unchangedCount = 0
        var deferredCount = 0
        var failures: [ExternalCorpusFailure] = []

        for candidate in scan.candidates {
            if checkpoint.entries[candidate.url.path]?.fingerprint == candidate.fingerprint {
                unchangedCount += 1
                continue
            }
            guard uploaded.count < max(0, uploadLimit) else {
                deferredCount += 1
                continue
            }
            do {
                // Source-provenance (e.g. mnemo_source_kind) comes in via
                // extraMetadata; the crawler's own keys take precedence.
                var metadata = extraMetadata
                metadata[ExternalCorpusMetadata.originalPath] = candidate.url.path
                metadata[ExternalCorpusMetadata.relativePath] = candidate.relativePath
                metadata[ExternalCorpusMetadata.rootPath] = scan.root.path
                metadata[ExternalCorpusMetadata.fingerprint] = candidate.fingerprint
                let id = try await uploader.uploadFile(
                    candidate.url,
                    container: container,
                    metadata: metadata
                )
                uploaded.append(.init(path: candidate.url.path, documentId: id))
                checkpoint.entries[candidate.url.path] = .init(
                    fingerprint: candidate.fingerprint,
                    documentId: id
                )
                try save(checkpoint)
            } catch {
                failures.append(.init(path: candidate.url.path, message: String(describing: error)))
            }
        }

        return .init(
            scan: scan,
            uploaded: uploaded,
            unchangedCount: unchangedCount,
            deferredCount: deferredCount,
            failures: failures
        )
    }

    private func loadCheckpoint() -> ExternalCorpusCheckpoint {
        guard let data = try? Data(contentsOf: checkpointURL),
              let decoded = try? JSONDecoder().decode(ExternalCorpusCheckpoint.self, from: data)
        else { return .init() }
        return decoded
    }

    private func save(_ checkpoint: ExternalCorpusCheckpoint) throws {
        try FileManager.default.createDirectory(
            at: checkpointURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(checkpoint).write(to: checkpointURL, options: .atomic)
    }
}
