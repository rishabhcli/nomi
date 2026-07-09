import Foundation

/// The engine build (v0.0.3) can only extract media via cloud APIs, which the
/// invariant forbids. Mnemo therefore extracts media ON DEVICE and posts the
/// text as a *companion document* linked to the failed original by metadata.
/// The original file stays the citation target; the companion carries the
/// searchable text. All of it loopback-only.
public enum MediaCompanion {
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
