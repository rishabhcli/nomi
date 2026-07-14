import Foundation

public enum StarterProfileSource: String, CaseIterable, Codable, Hashable, Sendable {
    case documents
    case desktop
    case downloads

    public var title: String { rawValue.capitalized }

    public func url(in homeDirectory: URL) -> URL {
        homeDirectory.appending(path: title, directoryHint: .isDirectory)
    }
}

public struct StarterProfileLimits: Equatable, Sendable {
    public let maxFiles: Int
    public let maxFileBytes: Int
    public let maxTotalBytes: Int
    public let maxContextCharacters: Int
    public let maxEnumeratedEntries: Int
    public let maxProfileCharacters: Int

    public init(maxFiles: Int = 8, maxFileBytes: Int = 1_048_576,
                maxTotalBytes: Int = 4_194_304, maxContextCharacters: Int = 24_000,
                maxEnumeratedEntries: Int = 2_000, maxProfileCharacters: Int = 6_000) {
        self.maxFiles = max(1, maxFiles)
        self.maxFileBytes = max(1, maxFileBytes)
        self.maxTotalBytes = max(1, maxTotalBytes)
        self.maxContextCharacters = max(1, maxContextCharacters)
        self.maxEnumeratedEntries = max(1, maxEnumeratedEntries)
        self.maxProfileCharacters = max(1, maxProfileCharacters)
    }
}

public struct StarterProfileCandidate: Equatable, Sendable {
    public let url: URL
    public let byteCount: Int
    public let modifiedAt: Date

    public init(url: URL, byteCount: Int, modifiedAt: Date) {
        self.url = url
        self.byteCount = byteCount
        self.modifiedAt = modifiedAt
    }
}

public protocol StarterProfileFileAccess: Sendable {
    /// Metadata enumeration only. Implementations must not read file contents.
    func candidates(in roots: [URL], limits: StarterProfileLimits) async throws -> [StarterProfileCandidate]
    /// Called only after explicit consent and source selection.
    func extractText(from candidate: StarterProfileCandidate, maximumBytes: Int) async throws -> String?
}

public struct LocalStarterProfileFileAccess: StarterProfileFileAccess {
    public static let supportedExtensions: Set<String> = [
        "txt", "md", "markdown", "csv", "tsv", "json", "jsonl", "yaml", "yml", "toml",
        "xml", "html", "htm", "pdf", "doc", "docx", "rtf", "rtfd", "odt", "webarchive",
    ]
    private static let directlyReadableExtensions: Set<String> = [
        "txt", "md", "markdown", "csv", "tsv", "json", "jsonl", "yaml", "yml", "toml",
        "xml", "html", "htm",
    ]
    private let scheduler: WorkScheduler?

    public init(scheduler: WorkScheduler? = nil) { self.scheduler = scheduler }

    public func candidates(in roots: [URL], limits: StarterProfileLimits) async throws -> [StarterProfileCandidate] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
                                      .contentModificationDateKey]
        var inspected = 0
        var result: [StarterProfileCandidate] = []
        let manager = FileManager.default

        for root in roots where inspected < limits.maxEnumeratedEntries {
            guard let enumerator = manager.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }
            while let url = enumerator.nextObject() as? URL, inspected < limits.maxEnumeratedEntries {
                try Task.checkCancellation()
                inspected += 1
                guard Self.supportedExtensions.contains(url.pathExtension.lowercased()),
                      let values = try? url.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true,
                      values.isSymbolicLink != true,
                      let byteCount = values.fileSize,
                      byteCount > 0,
                      byteCount <= limits.maxFileBytes
                else { continue }
                result.append(StarterProfileCandidate(
                    url: url,
                    byteCount: byteCount,
                    modifiedAt: values.contentModificationDate ?? .distantPast
                ))
            }
        }
        return result
    }

    public func extractText(from candidate: StarterProfileCandidate, maximumBytes: Int) async throws -> String? {
        try Task.checkCancellation()
        guard maximumBytes > 0, candidate.byteCount <= maximumBytes else { return nil }
        let current = try candidate.url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard current.isRegularFile == true, current.isSymbolicLink != true,
              let currentBytes = current.fileSize, currentBytes > 0, currentBytes <= maximumBytes else { return nil }
        let ext = candidate.url.pathExtension.lowercased()
        if Self.directlyReadableExtensions.contains(ext) {
            let handle = try FileHandle(forReadingFrom: candidate.url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: maximumBytes) ?? Data()
            return String(data: data, encoding: .utf8)
        }
        return try await LocalExtractor.extract(candidate.url, scheduler: scheduler)
    }
}

public enum StarterProfilePreference: String, Equatable, Sendable {
    case pending
    case completed
    case skipped
}

public protocol StarterProfilePreferenceStoring: Sendable {
    func load() async -> StarterProfilePreference
    /// Atomically applies a terminal transition. Completed and skipped states
    /// cannot overwrite one another, and cancelled work cannot commit completion.
    func transition(to preference: StarterProfilePreference) async -> StarterProfilePreference
}

public enum StarterProfilePreferenceTransition {
    public static func resolve(current: StarterProfilePreference,
                               requested: StarterProfilePreference,
                               isCancelled: Bool = false) -> StarterProfilePreference {
        guard current == .pending else { return current }
        if requested == .completed, isCancelled { return current }
        return requested
    }
}

public actor UserDefaultsStarterProfilePreferenceStore: StarterProfilePreferenceStoring {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard,
                key: String = "ai.mnemo.starter-profile.status.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> StarterProfilePreference {
        guard let raw = defaults.string(forKey: key), let value = StarterProfilePreference(rawValue: raw)
        else { return .pending }
        return value
    }

    public func transition(to preference: StarterProfilePreference) -> StarterProfilePreference {
        let current = load()
        let next = StarterProfilePreferenceTransition.resolve(
            current: current,
            requested: preference,
            isCancelled: Task.isCancelled
        )
        if next != current { defaults.set(next.rawValue, forKey: key) }
        return next
    }
}

public protocol StarterProfileCorpusChecking: DocumentIndexing, MemoryStoring {}
extension EngineClient: StarterProfileCorpusChecking {}

public enum StarterProfileEligibility: Equatable, Sendable { case offer, hidden }

public enum StarterProfileProgress: Equatable, Sendable {
    case findingFiles
    case reading(current: Int, total: Int, name: String)
    case generating
    case indexing(current: Int, total: Int, name: String)
    case saving
}

public struct StarterProfileBuildResult: Equatable, Sendable {
    public let profile: String
    public let sampledFiles: [String]
    public let indexedFiles: Int
    public let consumedBytes: Int
    public let contextCharacters: Int
}

public enum StarterProfileError: Error, Equatable, Sendable {
    case notEligible
    case noSourcesSelected
    case sourceReadFailed
    case noReadableFiles
    case generationFailed
    case emptyProfile
    case profileWriteFailed
}

public enum StarterProfilePresentation {
    public static func message(for error: StarterProfileError) -> String {
        switch error {
        case .notEligible: return "Starter customization is no longer available for this memory."
        case .noSourcesSelected: return "Choose at least one folder to build your starter profile."
        case .sourceReadFailed: return "I couldn't read the selected folders. Nothing was saved."
        case .noReadableFiles: return "I couldn't find a supported recent file in those folders."
        case .generationFailed: return "The local model couldn't build your profile. Nothing was saved."
        case .emptyProfile: return "The local model didn't produce a usable profile. Nothing was saved."
        case .profileWriteFailed: return "The profile couldn't be saved to local memory."
        }
    }

    public static func status(for progress: StarterProfileProgress) -> String {
        switch progress {
        case .findingFiles: return "Finding recent supported files…"
        case .reading(let current, let total, let name): return "Reading \(name) · \(current) of \(total)"
        case .generating: return "Building your profile on-device…"
        case .indexing(let current, let total, let name): return "Indexing \(name) · \(current) of \(total)"
        case .saving: return "Saving to local memory…"
        }
    }
}

public enum StarterProfileRedactor {
    private static let patterns: [(String, String)] = [
        (#"(?i)\b((?:[a-z0-9]+[_-])*(?:api[_-]?key|access[_-]?token|refresh[_-]?token|token|password|passwd|client[_-]?secret|secret))\b\s*[:=]\s*(?:\"[^\"\n]*\"|'[^'\n]*'|[^\s,;]+)"#, "$1=[REDACTED]"),
        (#"(?i)\bbearer\s+[A-Za-z0-9._~+/=-]{8,}"#, "Bearer [REDACTED]"),
        (#"\bsk-[A-Za-z0-9_-]{12,}\b"#, "[REDACTED]"),
        (#"\bAKIA[A-Z0-9]{16}\b"#, "[REDACTED]"),
        (#"\bgh[pousr]_[A-Za-z0-9]{20,}\b"#, "[REDACTED]"),
    ]

    public static func redact(_ text: String) -> String {
        patterns.reduce(text) { value, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern.0) else { return value }
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            return regex.stringByReplacingMatches(in: value, range: range, withTemplate: pattern.1)
        }
    }
}

public struct StarterProfileOnboardingService: Sendable {
    private let corpus: any StarterProfileCorpusChecking
    private let uploader: any CorpusFileUploading
    private let generator: any Generating
    private let files: any StarterProfileFileAccess
    private let preferences: any StarterProfilePreferenceStoring
    private let container: String
    private let limits: StarterProfileLimits

    public init(corpus: any StarterProfileCorpusChecking, uploader: any CorpusFileUploading,
                generator: any Generating, files: any StarterProfileFileAccess,
                preferences: any StarterProfilePreferenceStoring, container: String = "mnemo",
                limits: StarterProfileLimits = StarterProfileLimits()) {
        self.corpus = corpus
        self.uploader = uploader
        self.generator = generator
        self.files = files
        self.preferences = preferences
        self.container = container
        self.limits = limits
    }

    public func eligibility() async throws -> StarterProfileEligibility {
        guard await preferences.load() == .pending else { return .hidden }
        async let documents = corpus.documentsList(container: container)
        async let memories = corpus.listMemories(container: container)
        let (documentRows, memoryRows) = try await (documents, memories)
        return documentRows.isEmpty && memoryRows.isEmpty ? .offer : .hidden
    }

    public func skip() async { _ = await preferences.transition(to: .skipped) }

    public func build(from sources: Set<StarterProfileSource>, homeDirectory: URL,
                      progress: @escaping @Sendable (StarterProfileProgress) -> Void) async throws -> StarterProfileBuildResult {
        guard !sources.isEmpty else { throw StarterProfileError.noSourcesSelected }
        guard try await eligibility() == .offer else { throw StarterProfileError.notEligible }
        progress(.findingFiles)

        let roots = sources.sorted { $0.rawValue < $1.rawValue }.map { $0.url(in: homeDirectory) }
        let discovered: [StarterProfileCandidate]
        do { discovered = try await files.candidates(in: roots, limits: limits) }
        catch is CancellationError { throw CancellationError() }
        catch { throw StarterProfileError.sourceReadFailed }

        let selected = boundedSelection(discovered)
        var readable: [(candidate: StarterProfileCandidate, text: String)] = []
        var remainingContext = limits.maxContextCharacters
        for (index, candidate) in selected.enumerated() {
            try Task.checkCancellation()
            progress(.reading(current: index + 1, total: selected.count, name: candidate.url.lastPathComponent))
            guard remainingContext > 0 else { continue }
            let extracted: String?
            do { extracted = try await files.extractText(from: candidate, maximumBytes: limits.maxFileBytes) }
            catch is CancellationError { throw CancellationError() }
            catch { continue }
            guard let extracted else { continue }
            let text = StarterProfileRedactor.redact(extracted)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let header = "[Source: \(candidate.url.lastPathComponent)]\n"
            let separatorCount = readable.isEmpty ? 0 : 2
            guard !text.isEmpty, remainingContext > header.count + separatorCount else { continue }
            let clipped = String(text.prefix(remainingContext - header.count - separatorCount))
            readable.append((candidate, header + clipped))
            remainingContext -= separatorCount + header.count + clipped.count
        }
        guard !readable.isEmpty else { throw StarterProfileError.noReadableFiles }

        progress(.generating)
        let context = readable.map(\.text).joined(separator: "\n\n")
        var profile = ""
        do {
            for try await token in generator.stream(
                system: Self.profileSystemPrompt,
                prompt: "Create my starter customization from only these local sources:\n\n\(context)",
                effort: "low"
            ) {
                try Task.checkCancellation()
                let remaining = limits.maxProfileCharacters - profile.count
                guard remaining > 0 else { break }
                profile += String(token.prefix(remaining))
            }
        } catch is CancellationError { throw CancellationError() }
        catch { throw StarterProfileError.generationFailed }
        profile = StarterProfileRedactor.redact(profile)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard profile.count >= 40 else { throw StarterProfileError.emptyProfile }

        var indexed = 0
        for (index, item) in readable.enumerated() {
            try Task.checkCancellation()
            progress(.indexing(current: index + 1, total: readable.count, name: item.candidate.url.lastPathComponent))
            let metadata = [
                "mnemo_source_kind": "starter-profile",
                "mnemo_onboarding": "v1",
                "mnemo_original_path": item.candidate.url.path,
            ]
            do {
                _ = try await uploader.uploadFile(item.candidate.url, container: container, metadata: metadata)
                indexed += 1
            } catch is CancellationError { throw CancellationError() }
            catch { continue }
        }

        try Task.checkCancellation()
        progress(.saving)
        do {
            _ = try await corpus.createMemory(content: profile, isStatic: false,
                                              forgetAfter: nil, container: container)
        } catch is CancellationError { throw CancellationError() }
        catch { throw StarterProfileError.profileWriteFailed }
        try Task.checkCancellation()
        let persisted = await preferences.transition(to: .completed)
        guard persisted == .completed else { throw CancellationError() }
        return StarterProfileBuildResult(
            profile: profile,
            sampledFiles: readable.map { $0.candidate.url.lastPathComponent },
            indexedFiles: indexed,
            consumedBytes: readable.reduce(0) { $0 + $1.candidate.byteCount },
            contextCharacters: context.count
        )
    }

    private func boundedSelection(_ candidates: [StarterProfileCandidate]) -> [StarterProfileCandidate] {
        let sorted = candidates.sorted {
            if $0.modifiedAt != $1.modifiedAt { return $0.modifiedAt > $1.modifiedAt }
            return $0.url.path < $1.url.path
        }
        var selected: [StarterProfileCandidate] = []
        var bytes = 0
        for candidate in sorted {
            guard selected.count < limits.maxFiles else { break }
            guard candidate.byteCount > 0, candidate.byteCount <= limits.maxFileBytes,
                  bytes + candidate.byteCount <= limits.maxTotalBytes else { continue }
            selected.append(candidate)
            bytes += candidate.byteCount
        }
        return selected
    }

    private static let profileSystemPrompt = """
    You build a concise personalization profile from local user-provided files. Use only explicit facts in the sources. Do not infer sensitive traits, credentials, health, politics, or relationships. Never reproduce secrets or long quotes. Write 6-12 short first-person bullets covering durable work, projects, tools, interests, and communication preferences when supported. Omit unsupported categories and do not add an introduction.
    """
}
