import Foundation

/// The `file` source: crawls a directory tree — a home folder, or a mounted
/// external volume like the 2TB SanDisk SSD — and ingests supported files into the
/// `files` container. Each document is stamped with `mnemo_source_kind = file` and
/// its real on-disk path (so a citation opens the actual `/Volumes/…` file in
/// Finder), and the crawl is resumable/incremental via the ingestor's checkpoint.
///
/// A thin `IngestSource` adapter over the resumable `ExternalCorpusIngestor`, so a
/// whole-machine crawl plugs into the same registry, scheduling, and status model
/// as every other source. (M13 → M15)
public struct FileTreeSource: IngestSource {
    public let kind: SourceKind = .file
    public let root: URL
    private let ingestor: ExternalCorpusIngestor

    public init(root: URL, ingestor: ExternalCorpusIngestor) {
        self.root = root
        self.ingestor = ingestor
    }

    @discardableResult
    public func sync(limit: Int) async throws -> IngestReport {
        let report = try await ingestor.ingest(
            root: root,
            container: container,
            uploadLimit: limit,
            extraMetadata: SourceProvenance.stamp(kind)
        )
        return IngestReport(
            kind: kind,
            container: container,
            uploaded: report.uploaded.count,
            unchanged: report.unchangedCount,
            deferred: report.deferredCount,
            failures: report.failures.count
        )
    }
}
