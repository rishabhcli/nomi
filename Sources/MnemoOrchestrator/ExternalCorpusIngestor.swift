import Foundation

public protocol CorpusFileUploading: Sendable {
    func uploadFile(
        _ fileURL: URL,
        container: String?,
        metadata: [String: String]
    ) async throws -> String
}

public protocol CorpusDocumentDeleting: Sendable {
    func deleteDocument(_ documentId: String) async throws
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
    public let deletedCount: Int
    public let failures: [ExternalCorpusFailure]
}

private struct ExternalCorpusCheckpoint: Codable {
    struct Entry: Codable {
        let fingerprint: String
        let documentId: String
        var staleDocumentIds: [String]

        init(fingerprint: String, documentId: String, staleDocumentIds: [String] = []) {
            self.fingerprint = fingerprint
            self.documentId = documentId
            self.staleDocumentIds = staleDocumentIds
        }

        enum CodingKeys: String, CodingKey {
            case fingerprint
            case documentId
            case staleDocumentIds
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            fingerprint = try values.decode(String.self, forKey: .fingerprint)
            documentId = try values.decode(String.self, forKey: .documentId)
            staleDocumentIds = try values.decodeIfPresent(
                [String].self,
                forKey: .staleDocumentIds
            ) ?? []
        }
    }

    var entries: [String: Entry] = [:]
}

private struct PendingExternalCorpusReconciliation {
    let rootPath: String
    let container: String
    let scan: ExternalCorpusScanReport
    let candidates: [ExternalCorpusCandidate]
    var nextCandidateIndex: Int
}

/// Sequential uploader with a durable checkpoint. Sequential upload keeps a
/// multi-terabyte source from flooding the two-worker local engine.
public actor ExternalCorpusIngestor {
    private let uploader: CorpusFileUploading
    private let deleter: CorpusDocumentDeleting?
    private let scanner: ExternalCorpusScanner
    private let checkpointURL: URL
    private let scheduler: WorkScheduler?
    private var latestScan: ExternalCorpusScanReport?
    private var pending: PendingExternalCorpusReconciliation?

    public init(
        uploader: CorpusFileUploading,
        deleter: CorpusDocumentDeleting? = nil,
        scanner: ExternalCorpusScanner,
        checkpointURL: URL,
        scheduler: WorkScheduler? = nil
    ) {
        self.uploader = uploader
        self.deleter = deleter
        self.scanner = scanner
        self.checkpointURL = checkpointURL
        self.scheduler = scheduler
    }

    public func ingest(
        root: URL,
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String] = [:]
    ) async throws -> ExternalCorpusIngestReport {
        try Task.checkCancellation()
        let normalizedRoot = root.standardizedFileURL.resolvingSymlinksInPath().path
        if let pending,
           pending.rootPath == normalizedRoot,
           pending.container == container {
            return try await processPending(
                uploadLimit: uploadLimit,
                extraMetadata: extraMetadata
            )
        }

        pending = nil
        let scan = try await scanner.scan(root: root, scheduler: scheduler)
        latestScan = scan
        return try await beginReconciliation(
            scan: scan,
            candidates: scan.candidates,
            container: container,
            uploadLimit: uploadLimit,
            extraMetadata: extraMetadata
        )
    }

    public func ingestChanges(
        root: URL,
        batch: FileChangeBatch,
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String]
    ) async throws -> ExternalCorpusIngestReport {
        try Task.checkCancellation()
        pending = nil
        switch batch.reason {
        case .incremental:
            scanner.invalidateFingerprints(for: batch.paths)
        case .eventLossFullScan:
            scanner.invalidateFingerprints(for: [root.path])
        case .periodicFullScan:
            break
        }

        let scan: ExternalCorpusScanReport
        let workCandidates: [ExternalCorpusCandidate]
        if batch.requiresFullScan || latestScan?.root.path != root.standardizedFileURL
            .resolvingSymlinksInPath().path {
            scan = try await scanner.scan(root: root, scheduler: scheduler)
            workCandidates = scan.candidates
        } else {
            let delta = try await scanner.scanChanges(
                root: root,
                paths: batch.paths,
                scheduler: scheduler
            )
            scan = merge(delta: delta, into: latestScan!, changedPaths: batch.paths)
            workCandidates = delta.candidates
        }
        latestScan = scan
        return try await beginReconciliation(
            scan: scan,
            candidates: workCandidates,
            container: container,
            uploadLimit: uploadLimit,
            extraMetadata: extraMetadata
        )
    }

    private func beginReconciliation(
        scan: ExternalCorpusScanReport,
        candidates: [ExternalCorpusCandidate],
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String]
    ) async throws -> ExternalCorpusIngestReport {
        var checkpoint = loadCheckpoint()
        var deletedCount = 0
        var failures = scan.enumerationFailurePaths.map {
            ExternalCorpusFailure(
                path: $0,
                message: "Filesystem enumeration was incomplete; deletion was deferred."
            )
        }

        if scan.isComplete, let deleter {
            let livePaths = Set(scan.candidates.map { $0.url.path })
            for path in checkpoint.entries.keys.sorted() where !livePaths.contains(path) {
                try await waitForInteractiveWork()
                guard let entry = checkpoint.entries[path] else { continue }
                let ids = [entry.documentId] + entry.staleDocumentIds
                var remaining: [String] = []
                for id in ids {
                    do {
                        try await waitForInteractiveWork()
                        try await deleter.deleteDocument(id)
                        deletedCount += 1
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        remaining.append(id)
                        failures.append(.init(path: path, message: String(describing: error)))
                    }
                }
                if remaining.isEmpty {
                    checkpoint.entries.removeValue(forKey: path)
                } else {
                    checkpoint.entries[path] = .init(
                        fingerprint: entry.fingerprint,
                        documentId: remaining[0],
                        staleDocumentIds: Array(remaining.dropFirst())
                    )
                }
                try save(checkpoint)
            }
        }

        pending = .init(
            rootPath: scan.root.path,
            container: container,
            scan: scan,
            candidates: candidates,
            nextCandidateIndex: 0
        )
        return try await processPending(
            uploadLimit: uploadLimit,
            extraMetadata: extraMetadata,
            initialDeletedCount: deletedCount,
            initialFailures: failures
        )
    }

    private func processPending(
        uploadLimit: Int,
        extraMetadata: [String: String],
        initialDeletedCount: Int = 0,
        initialFailures: [ExternalCorpusFailure] = []
    ) async throws -> ExternalCorpusIngestReport {
        guard var session = pending else {
            throw ExternalCorpusScanError.enumerationFailed("No active reconciliation")
        }
        var checkpoint = loadCheckpoint()
        var uploaded: [ExternalCorpusUpload] = []
        var unchangedCount = 0
        var deletedCount = initialDeletedCount
        var failures = initialFailures
        var attempts = 0
        let attemptLimit = max(1, uploadLimit)

        while session.nextCandidateIndex < session.candidates.count {
            try await waitForInteractiveWork()
            let candidate = session.candidates[session.nextCandidateIndex]
            if checkpoint.entries[candidate.url.path]?.fingerprint == candidate.fingerprint {
                unchangedCount += 1
                session.nextCandidateIndex += 1
                continue
            }
            guard attempts < attemptLimit else { break }
            attempts += 1
            do {
                var metadata = extraMetadata
                metadata[ExternalCorpusMetadata.originalPath] = candidate.url.path
                metadata[ExternalCorpusMetadata.relativePath] = candidate.relativePath
                metadata[ExternalCorpusMetadata.rootPath] = session.scan.root.path
                metadata[ExternalCorpusMetadata.fingerprint] = candidate.fingerprint
                let id = try await uploader.uploadFile(
                    candidate.url,
                    container: session.container,
                    metadata: metadata
                )
                uploaded.append(.init(path: candidate.url.path, documentId: id))
                let previous = checkpoint.entries[candidate.url.path]
                let staleDocumentIds = previous.map { entry in
                    (entry.staleDocumentIds + [entry.documentId]).filter { $0 != id }
                } ?? []
                checkpoint.entries[candidate.url.path] = .init(
                    fingerprint: candidate.fingerprint,
                    documentId: id,
                    staleDocumentIds: staleDocumentIds
                )
                try save(checkpoint)
                if let deleter,
                   var current = checkpoint.entries[candidate.url.path],
                   !current.staleDocumentIds.isEmpty {
                    var remaining: [String] = []
                    for staleId in current.staleDocumentIds {
                        do {
                            try await waitForInteractiveWork()
                            try await deleter.deleteDocument(staleId)
                            deletedCount += 1
                        } catch is CancellationError {
                            throw CancellationError()
                        } catch {
                            remaining.append(staleId)
                            failures.append(.init(
                                path: candidate.url.path,
                                message: String(describing: error)
                            ))
                        }
                    }
                    current.staleDocumentIds = remaining
                    checkpoint.entries[candidate.url.path] = current
                    try save(checkpoint)
                }
            } catch is CancellationError {
                pending = session
                throw CancellationError()
            } catch {
                failures.append(.init(path: candidate.url.path, message: String(describing: error)))
            }
            session.nextCandidateIndex += 1
        }

        let deferredCount = session.candidates.count - session.nextCandidateIndex
        pending = deferredCount > 0 ? session : nil
        return .init(
            scan: session.scan,
            uploaded: uploaded,
            unchangedCount: unchangedCount,
            deferredCount: deferredCount,
            deletedCount: deletedCount,
            failures: failures
        )
    }

    private func merge(
        delta: ExternalCorpusScanReport,
        into previous: ExternalCorpusScanReport,
        changedPaths: [String]
    ) -> ExternalCorpusScanReport {
        let roots = changedPaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        func isChanged(_ path: String) -> Bool {
            roots.contains { path == $0 || path.hasPrefix($0 + "/") }
        }
        let retainedCandidates = previous.candidates.filter { !isChanged($0.url.path) }
        let retainedSkipped = previous.skipped.filter {
            !isChanged(previous.root.appending(path: $0.path).path)
        }
        let retainedFailures = previous.enumerationFailurePaths.filter { !isChanged($0) }
        return .init(
            root: previous.root,
            candidates: (retainedCandidates + delta.candidates).sorted {
                $0.relativePath < $1.relativePath
            },
            skipped: (retainedSkipped + delta.skipped).sorted { $0.path < $1.path },
            enumerationFailurePaths: Array(Set(
                retainedFailures + delta.enumerationFailurePaths
            )).sorted()
        )
    }

    private func waitForInteractiveWork() async throws {
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

extension ExternalCorpusIngestor: ExternalCorpusReconciling {}
