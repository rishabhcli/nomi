import Foundation

/// The engine build (v0.0.3) can only extract media via cloud APIs, which the
/// invariant forbids. Mnemo therefore extracts media ON DEVICE and posts the
/// text as a *companion document* linked to the failed original by metadata.
/// The original file stays the citation target; the companion carries the
/// searchable text. All of it loopback-only.
public enum MediaCompanion {
    // A-101: lifecycle
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] { switch branch { case .routeAmbiguity: return [.reasoning(["Ambiguous route"])]; case .emptyEvidence: return [.sources([]), .token("No match.")]; case .retry: return [.retrying("Retrying…")] } }
    public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-157: grounding
    public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    // A-305: intelligence
    // MARK: - Expressiveness (beats-Siri offline)
        /// Shapes cross-doc synthesis as timeline/table/bullets for offline rendering.
        public static func expressivenessShape(_ items: [String], as shape: AnswerShape) -> String {
            switch shape {
            case .timeline: return items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            case .comparison: return "| Item | Detail |\n|------|--------|\n" + items.map { "| \($0) | |" }.joined(separator: "\n")
            case .list: return items.map { "- \($0)" }.joined(separator: "\n")
            default: return items.joined(separator: "; ")
            }
        }

    // A-253: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return !constituents.isEmpty
        }

    // A-201: memory
    // MARK: - Memory dynamics (M6)
        /// Active memories only — forgotten and TTL-expired facts are excluded.
        public static func memoryDynamicsActive(_ entry: MemoryEntry, now: Date = Date()) -> Bool {
            guard entry.isLatest && !entry.isForgotten else { return false }
            guard let forgetAfter = entry.forgetAfter,
                  let expiry = ISO8601DateFormatter().date(from: forgetAfter) else { return true }
            return now < expiry
        }

        public static func memoryDynamicsFilter(_ entries: [MemoryEntry], now: Date = Date()) -> [MemoryEntry] {
            entries.filter { memoryDynamicsActive($0, now: now) }
        }

    public static let companionOfKey = "mnemo_companion_of"
    public static let originalPathKey = "mnemo_original_path"
    public static let extractionKey = "mnemo_extraction"

    static let mediaExtensions: Set<String> = [
        "png", "jpg", "jpeg", "tiff", "gif", "heic", "webp", "bmp",
        "pdf", "docx", "doc", "rtf", "rtfd", "odt",
        "m4a", "mp3", "wav", "aiff", "aac", "flac", "ogg",
        "mp4", "mov", "webm", "m4v",
    ]

    public static func isMediaPath(_ path: String) -> Bool {
        mediaExtensions.contains((path as NSString).pathExtension.lowercased())
    }

    /// The doc id this companion covers, or nil if not a companion.
    public static func companionOf(_ doc: DocumentMeta) -> String? {
        doc.metadata?[companionOfKey]
    }

    /// Failed media documents that have no companion yet — the extraction worklist.
    public static func needingExtraction(docs: [DocumentMeta]) -> [DocumentMeta] {
        let covered = Set(docs.compactMap(companionOf))
        return docs.filter { d in
            d.state == .error
                && !covered.contains(d.id)
                && companionOf(d) == nil
                && isMediaPath(d.filepath ?? "")
        }
    }

    /// Presentation state: a failed media doc whose companion is ready IS
    /// searchable, so it presents as ready.
    public static func effectiveState(of doc: DocumentMeta, in all: [DocumentMeta]) -> ItemState {
        guard doc.state == .error else { return doc.state }
        if let companion = all.first(where: { companionOf($0) == doc.id }) {
            return companion.state == .ready ? .ready : companion.state
        }
        return .error
    }
}

/// Creates documents in the engine (faked in tests).
public protocol DocumentCreating: Sendable {
    @discardableResult
    func createDocument(content: String, customId: String?, container: String?,
                        metadata: [String: String]) async throws -> String
}

/// One sync pass: find failed media docs without companions, extract each
/// on-device, and post the companion text document.
public struct MediaIngestor: Sendable {
    let creator: DocumentCreating
    let container: String?
    let mountRoot: String
    let extract: @Sendable (URL) async throws -> String?

    public init(creator: DocumentCreating, container: String?, mountRoot: String,
                extract: @escaping @Sendable (URL) async throws -> String? = LocalExtractor.extract) {
        self.creator = creator
        self.container = container
        self.mountRoot = mountRoot
        self.extract = extract
    }

    /// Returns the number of companions created.
    @discardableResult
    public func sync(docs: [DocumentMeta]) async -> Int {
        var created = 0
        for doc in MediaCompanion.needingExtraction(docs: docs) {
            guard let enginePath = doc.filepath else { continue }
            let url = URL(fileURLWithPath: mountRoot + enginePath)
            guard let text = try? await extract(url), !text.isEmpty else { continue }
            let name = (enginePath as NSString).lastPathComponent
            let content = "# \(name)\n\n\(text)"
            let metadata = [
                MediaCompanion.companionOfKey: doc.id,
                MediaCompanion.originalPathKey: enginePath,
                MediaCompanion.extractionKey: "on-device",
            ]
            if (try? await creator.createDocument(
                content: content, customId: "mnemo-companion-\(doc.id)",
                container: container, metadata: metadata)) != nil {
                created += 1
            }
        }
        return created
    }
}

// M11 scheduling budget (A-357)
extension MediaCompanion {
    public enum Scheduling {
        public static let budgetUs: UInt64 = 150
        public static func registerBudget() { SchedulingBudget.register("MediaCompanion", budgetUs: budgetUs) }
        /// Cooperative yield hook for background callers on the interactive path.
        public static func yieldIfInteractiveWaiting(_ scheduler: WorkScheduler?) async {
            guard let scheduler, await scheduler.shouldBackgroundYield else { return }
        }
    }
}
