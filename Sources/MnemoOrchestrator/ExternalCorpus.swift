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
    public let enumerationFailurePaths: [String]

    public init(
        root: URL,
        candidates: [ExternalCorpusCandidate],
        skipped: [ExternalCorpusSkipped],
        enumerationFailurePaths: [String] = []
    ) {
        self.root = root
        self.candidates = candidates
        self.skipped = skipped
        self.enumerationFailurePaths = enumerationFailurePaths
    }

    public var isComplete: Bool { enumerationFailurePaths.isEmpty }

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
    /// Formats with a known on-device path in `LocalFirstCorpusUploader`.
    /// Anything else is skipped before upload so automatic indexing never
    /// retries a permanently unsupported format or reaches hosted extraction.
    public static let defaultExtensions: Set<String> = [
        "txt", "md", "markdown", "rtf", "csv", "tsv", "json", "jsonl",
        "yaml", "yml", "toml", "xml", "html", "htm",
        "pdf", "doc", "docx", "rtfd", "odt", "webarchive",
        "png", "jpg", "jpeg", "heic", "tiff", "webp", "gif", "bmp",
        "m4a", "mp3", "wav", "aiff", "aac", "flac", "ogg",
        "mp4", "mov", "webm", "m4v",
    ]

    public let maxFileBytes: Int64
    public let supportedExtensions: Set<String>

    public init(maxFileBytes: Int64, supportedExtensions: Set<String> = Self.defaultExtensions) {
        self.maxFileBytes = maxFileBytes
        self.supportedExtensions = Set(supportedExtensions.map { $0.lowercased() })
    }
}

private final class ExternalCorpusFingerprintCache: @unchecked Sendable {
    struct Key: Equatable {
        let byteCount: Int64
        let modifiedAtBits: UInt64
        let resourceIdentifier: String
    }

    private let lock = NSLock()
    private var entries: [String: (key: Key, digest: String)] = [:]

    func digest(for url: URL, key: Key) throws -> String {
        if let cached = lock.withLock({ entries[url.path] }), cached.key == key {
            return cached.digest
        }
        let digest = try ContentHash.sha256(of: url)
        lock.withLock { entries[url.path] = (key, digest) }
        return digest
    }

    func invalidate(paths: [String]) {
        let roots = paths.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        lock.withLock {
            entries = entries.filter { path, _ in
                !roots.contains { root in path == root || path.hasPrefix(root + "/") }
            }
        }
    }
}

/// Produces a deterministic, bounded plan for a large local folder. It never
/// follows symlinks or descends into application/document packages.
public struct ExternalCorpusScanner: Sendable {
    public let policy: ExternalCorpusPolicy
    private let fingerprintCache: ExternalCorpusFingerprintCache

    public init(policy: ExternalCorpusPolicy) {
        self.policy = policy
        self.fingerprintCache = ExternalCorpusFingerprintCache()
    }

    public func invalidateFingerprints(for paths: [String]) {
        fingerprintCache.invalidate(paths: paths)
    }

    public func scan(
        root: URL,
        scheduler: WorkScheduler? = nil
    ) async throws -> ExternalCorpusScanReport {
        try await scan(root: root, changedPaths: nil, scheduler: scheduler)
    }

    /// Scans only the FSEvent paths (or their descendants). Missing paths are
    /// valid here because they represent deletions and produce an empty delta.
    public func scanChanges(
        root: URL,
        paths: [String],
        scheduler: WorkScheduler? = nil
    ) async throws -> ExternalCorpusScanReport {
        try await scan(root: root, changedPaths: paths, scheduler: scheduler)
    }

    private func scan(
        root rawRoot: URL,
        changedPaths: [String]?,
        scheduler: WorkScheduler?
    ) async throws -> ExternalCorpusScanReport {
        try Task.checkCancellation()
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
            .contentModificationDateKey, .fileResourceIdentifierKey,
        ]
        let starts = Self.scanRoots(root: root, changedPaths: changedPaths)
        var candidates: [ExternalCorpusCandidate] = []
        var skipped: [ExternalCorpusSkipped] = []
        var enumerationFailures: [String] = []

        for start in starts {
            try await waitForInteractiveWork(scheduler)
            var startIsDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: start.path, isDirectory: &startIsDirectory) else {
                continue
            }
            if !startIsDirectory.boolValue {
                switch try await inspect(start, root: root, keys: keys, scheduler: scheduler) {
                case .candidate(let candidate): candidates.append(candidate)
                case .skipped(let item, _): skipped.append(item)
                case .ignored: break
                }
                continue
            }

            if start != root {
                switch try await inspect(start, root: root, keys: keys, scheduler: scheduler) {
                case .skipped(let item, _):
                    skipped.append(item)
                    continue
                case .candidate, .ignored:
                    break
                }
            }
            guard let enumerator = fileManager.enumerator(
                at: start,
                includingPropertiesForKeys: Array(keys),
                options: [],
                errorHandler: { url, _ in
                    enumerationFailures.append(url.path)
                    return true
                }
            ) else {
                enumerationFailures.append(start.path)
                continue
            }
            while let url = enumerator.nextObject() as? URL {
                try await waitForInteractiveWork(scheduler)
                switch try await inspect(url, root: root, keys: keys, scheduler: scheduler) {
                case .candidate(let candidate): candidates.append(candidate)
                case .skipped(let item, let skipDescendants):
                    if skipDescendants { enumerator.skipDescendants() }
                    skipped.append(item)
                case .ignored:
                    break
                }
            }
        }

        return .init(
            root: root,
            candidates: candidates.sorted { $0.relativePath < $1.relativePath },
            skipped: skipped.sorted { $0.path < $1.path },
            enumerationFailurePaths: Array(Set(enumerationFailures)).sorted()
        )
    }

    private enum Inspection {
        case candidate(ExternalCorpusCandidate)
        case skipped(ExternalCorpusSkipped, skipDescendants: Bool)
        case ignored
    }

    private func inspect(
        _ url: URL,
        root: URL,
        keys: Set<URLResourceKey>,
        scheduler: WorkScheduler?
    ) async throws -> Inspection {
        try await waitForInteractiveWork(scheduler)
        let resolvedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        let relativePath = Self.relativePath(for: resolvedURL, root: root)
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: keys)
        } catch {
            return .skipped(.init(path: relativePath, reason: .unreadable), skipDescendants: false)
        }
        if values.isHidden == true || url.lastPathComponent.hasPrefix(".")
            || url.lastPathComponent.hasSuffix(".smfs-error.txt") {
            return .skipped(
                .init(path: relativePath, reason: .hidden),
                skipDescendants: values.isDirectory == true
            )
        }
        if values.isPackage == true {
            return .skipped(.init(path: relativePath, reason: .package), skipDescendants: true)
        }
        if values.isSymbolicLink == true {
            return .skipped(.init(path: relativePath, reason: .symbolicLink), skipDescendants: true)
        }
        guard values.isRegularFile == true else { return .ignored }
        guard policy.supportedExtensions.contains(url.pathExtension.lowercased()) else {
            return .skipped(.init(path: relativePath, reason: .unsupportedType), skipDescendants: false)
        }
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return .skipped(.init(path: relativePath, reason: .unreadable), skipDescendants: false)
        }
        let byteCount = Int64(values.fileSize ?? 0)
        guard byteCount <= policy.maxFileBytes else {
            return .skipped(.init(path: relativePath, reason: .tooLarge), skipDescendants: false)
        }
        let modifiedAt = values.contentModificationDate ?? .distantPast
        try await waitForInteractiveWork(scheduler)
        do {
            return .candidate(.init(
                url: resolvedURL,
                relativePath: relativePath,
                byteCount: byteCount,
                modifiedAt: modifiedAt,
                fingerprint: try fingerprint(
                    url: resolvedURL,
                    relativePath: relativePath,
                    byteCount: byteCount,
                    modifiedAt: modifiedAt,
                    resourceIdentifier: String(describing: values.fileResourceIdentifier)
                )
            ))
        } catch {
            return .skipped(.init(path: relativePath, reason: .unreadable), skipDescendants: false)
        }
    }

    private static func scanRoots(root: URL, changedPaths: [String]?) -> [URL] {
        guard let changedPaths else { return [root] }
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let paths = Set(changedPaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path })
            .filter { $0 == root.path || $0.hasPrefix(rootPrefix) }
            .sorted()
        return paths.enumerated().compactMap { index, path in
            guard !paths[..<index].contains(where: { path.hasPrefix($0 + "/") }) else {
                return nil
            }
            return URL(fileURLWithPath: path)
        }
    }

    private func waitForInteractiveWork(_ scheduler: WorkScheduler?) async throws {
        guard let scheduler else {
            try Task.checkCancellation()
            return
        }
        while await scheduler.shouldBackgroundYield {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(100))
        }
        try Task.checkCancellation()
    }

    private static func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path.hasPrefix(rootPath) else { return url.lastPathComponent }
        return String(url.path.dropFirst(rootPath.count))
    }

    private func fingerprint(
        url: URL,
        relativePath: String,
        byteCount: Int64,
        modifiedAt: Date,
        resourceIdentifier: String
    ) throws -> String {
        let key = ExternalCorpusFingerprintCache.Key(
            byteCount: byteCount,
            modifiedAtBits: modifiedAt.timeIntervalSinceReferenceDate.bitPattern,
            resourceIdentifier: resourceIdentifier
        )
        let digest = try fingerprintCache.digest(for: url, key: key)
        return "\(relativePath)|\(byteCount)|\(modifiedAt.timeIntervalSinceReferenceDate.bitPattern)|\(digest)"
    }
}
