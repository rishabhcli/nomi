import Foundation

public struct VolumeID: RawRepresentable, Hashable, Codable, Sendable, Comparable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func < (lhs: VolumeID, rhs: VolumeID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A snapshot of the resource values used to decide whether a mounted volume
/// may be indexed. The UUID is optional because some synthetic/network mounts
/// do not provide one; those mounts fail closed.
public struct IndexedVolume: Equatable, Sendable {
    public let id: VolumeID?
    public let name: String
    public let root: URL
    public let isLocal: Bool
    public let isInternal: Bool
    public let isReadOnly: Bool
    public let isReadable: Bool
    public let isBrowsable: Bool
    /// Native volume format (for example `apfs` or `ExFAT`). Some external
    /// formats do not provide a usable FSEvents stream and need polling.
    public let fileSystemType: String?

    public init(
        id: VolumeID?,
        name: String,
        root: URL,
        isLocal: Bool,
        isInternal: Bool,
        isReadOnly: Bool,
        isReadable: Bool,
        isBrowsable: Bool = true,
        fileSystemType: String? = nil
    ) {
        self.id = id
        self.name = name
        self.root = root
        self.isLocal = isLocal
        self.isInternal = isInternal
        self.isReadOnly = isReadOnly
        self.isReadable = isReadable
        self.isBrowsable = isBrowsable
        self.fileSystemType = fileSystemType
    }
}

public enum VolumeWatcherStrategy: Equatable, Sendable {
    case fsevents
    case periodicFullScan
}

/// FSEvents can block while opening unsupported FSKit-backed volumes (observed
/// with ExFAT). Keep the native stream for Apple filesystems and fail closed to
/// bounded full reconciliation for every other format.
public enum VolumeWatcherPolicy {
    public static func strategy(forFileSystem rawValue: String?) -> VolumeWatcherStrategy {
        guard let value = rawValue?.lowercased() else { return .periodicFullScan }
        if value == "apfs" || value == "hfs" {
            return .fsevents
        }
        return .periodicFullScan
    }
}

public enum VolumeIneligibility: String, Equatable, Sendable {
    case missingUUID
    case notLocal
    case internalVolume
    case unreadable
    case notBrowsable
}

public enum VolumeEligibilityDecision: Equatable, Sendable {
    case eligible
    case ineligible(VolumeIneligibility)
}

public enum VolumeEligibility {
    public static func evaluate(_ volume: IndexedVolume) -> VolumeEligibilityDecision {
        guard volume.id != nil else { return .ineligible(.missingUUID) }
        guard volume.isLocal else { return .ineligible(.notLocal) }
        guard !volume.isInternal else { return .ineligible(.internalVolume) }
        guard volume.isReadable else { return .ineligible(.unreadable) }
        guard volume.isBrowsable else { return .ineligible(.notBrowsable) }
        return .eligible
    }
}

public enum VolumeEvent: Equatable, Sendable {
    case mounted(IndexedVolume)
    case unmounted(VolumeID)
}

public enum VolumeIndexAction: Equatable, Sendable {
    case start(IndexedVolume)
    case stop(VolumeID)
}

/// Pure mount policy. Identity is the volume UUID, so a duplicate notification
/// or a mount-path rename cannot create a second coordinator for one disk.
public struct VolumeIndexRegistry: Sendable {
    private var active: Set<VolumeID> = []

    public init() {}

    public var activeVolumeIDs: [VolumeID] { active.sorted() }

    public mutating func apply(_ event: VolumeEvent) -> VolumeIndexAction? {
        switch event {
        case .mounted(let volume):
            guard VolumeEligibility.evaluate(volume) == .eligible,
                  let id = volume.id,
                  active.insert(id).inserted
            else { return nil }
            return .start(volume)
        case .unmounted(let id):
            guard active.remove(id) != nil else { return nil }
            return .stop(id)
        }
    }
}

public enum VolumeActivityPhase: String, Equatable, Sendable {
    case detected
    case scanning
    case indexing
    case ready
    case error
    case unmounted
    case cancelled
}

public enum VolumeIndexingActivity: Equatable, Sendable {
    case detected(IndexedVolume)
    case scanning(IndexedVolume)
    case indexing(
        IndexedVolume,
        uploaded: Int,
        unchanged: Int,
        deleted: Int,
        deferred: Int
    )
    case ready(IndexedVolume, indexed: Int)
    case error(IndexedVolume, message: String)
    case unmounted(IndexedVolume)
    case cancelled(IndexedVolume)

    public var phase: VolumeActivityPhase {
        switch self {
        case .detected: .detected
        case .scanning: .scanning
        case .indexing: .indexing
        case .ready: .ready
        case .error: .error
        case .unmounted: .unmounted
        case .cancelled: .cancelled
        }
    }

    public var volume: IndexedVolume {
        switch self {
        case .detected(let volume), .scanning(let volume),
             .ready(let volume, _), .error(let volume, _),
             .unmounted(let volume), .cancelled(let volume),
             .indexing(let volume, _, _, _, _):
            volume
        }
    }
}

public enum VolumeActivityPolicy {
    public static func allowsTransition(
        from: VolumeActivityPhase?,
        to: VolumeActivityPhase
    ) -> Bool {
        switch (from, to) {
        case (nil, .detected),
             (.detected, .scanning),
             (.scanning, .indexing),
             (.scanning, .error),
             (.indexing, .indexing),
             (.indexing, .ready),
             (.indexing, .error),
             (.ready, .scanning),
             (.ready, .error),
             (.error, .scanning),
             (.detected, .unmounted),
             (.scanning, .unmounted),
             (.indexing, .unmounted),
             (.ready, .unmounted),
             (.error, .unmounted),
             (.detected, .cancelled),
             (.scanning, .cancelled),
             (.indexing, .cancelled),
             (.ready, .cancelled),
             (.error, .cancelled):
            true
        default:
            false
        }
    }
}

public enum FileChangeReason: Equatable, Sendable {
    case incremental
    case eventLossFullScan
    case periodicFullScan
}

public struct FileChangeBatch: Equatable, Sendable {
    public let paths: [String]
    public let reason: FileChangeReason
    public var requiresFullScan: Bool { reason != .incremental }

    public init(paths: [String], requiresFullScan: Bool) {
        self.init(
            paths: paths,
            reason: requiresFullScan ? .eventLossFullScan : .incremental
        )
    }

    public init(paths: [String], reason: FileChangeReason) {
        self.paths = Array(Set(paths)).sorted()
        self.reason = reason
    }
}

/// Pure accumulator used by the native FSEvents adapter. Events arriving during
/// the debounce interval collapse into one bounded reconciliation pass.
public struct FileChangeAccumulator: Sendable {
    private var paths: Set<String> = []
    private var requiresFullScan = false

    public init() {}

    public mutating func record(paths: [String], requiresFullScan: Bool) {
        self.paths.formUnion(paths)
        self.requiresFullScan = self.requiresFullScan || requiresFullScan
    }

    public mutating func drain() -> FileChangeBatch? {
        guard !paths.isEmpty || requiresFullScan else { return nil }
        let batch = FileChangeBatch(
            paths: Array(paths),
            requiresFullScan: requiresFullScan
        )
        paths.removeAll(keepingCapacity: true)
        requiresFullScan = false
        return batch
    }
}

public protocol VolumeObserving: Sendable {
    var events: AsyncStream<VolumeEvent> { get }
    func start()
    func stop()
}

public protocol VolumeFileWatching: Sendable {
    var changes: AsyncStream<FileChangeBatch> { get }
    func start() throws
    func stop()
}

/// Polling adapters arm their next timer only after the coordinator finishes
/// the preceding reconciliation. This prevents catch-up loops on large disks.
public protocol DemandDrivenVolumeFileWatching: VolumeFileWatching {
    func reconciliationDidFinish()
}

public protocol ExternalCorpusReconciling: Sendable {
    func ingest(
        root: URL,
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String]
    ) async throws -> ExternalCorpusIngestReport

    func ingestChanges(
        root: URL,
        batch: FileChangeBatch,
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String]
    ) async throws -> ExternalCorpusIngestReport
}

public extension ExternalCorpusReconciling {
    func ingestChanges(
        root: URL,
        batch: FileChangeBatch,
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String]
    ) async throws -> ExternalCorpusIngestReport {
        try await ingest(
            root: root,
            container: container,
            uploadLimit: uploadLimit,
            extraMetadata: extraMetadata
        )
    }
}
