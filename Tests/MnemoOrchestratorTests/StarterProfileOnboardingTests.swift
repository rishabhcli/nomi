import Foundation
import XCTest
@testable import MnemoOrchestrator

private actor StarterProfileTestPreferences: StarterProfilePreferenceStoring {
    var value: StarterProfilePreference = .pending
    func load() async -> StarterProfilePreference { value }
    func transition(to preference: StarterProfilePreference) async -> StarterProfilePreference {
        value = StarterProfilePreferenceTransition.resolve(
            current: value, requested: preference, isCancelled: Task.isCancelled
        )
        return value
    }
}

private actor LateCancelStarterProfilePreferences: StarterProfilePreferenceStoring {
    private var value: StarterProfilePreference = .pending
    private var completionArrived = false
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
    private var release: CheckedContinuation<Void, Never>?
    func load() async -> StarterProfilePreference { value }
    func transition(to preference: StarterProfilePreference) async -> StarterProfilePreference {
        if preference == .completed {
            completionArrived = true
            arrivalWaiters.forEach { $0.resume() }
            arrivalWaiters.removeAll()
            await withCheckedContinuation { release = $0 }
        }
        value = StarterProfilePreferenceTransition.resolve(
            current: value, requested: preference, isCancelled: Task.isCancelled
        )
        return value
    }
    func waitForCompletionAttempt() async {
        guard !completionArrived else { return }
        await withCheckedContinuation { arrivalWaiters.append($0) }
    }
    func releaseCompletion() {
        release?.resume()
        release = nil
    }
}

private actor StarterProfileTestCorpus: StarterProfileCorpusChecking, MemoryStoring {
    var documents: [DocumentMeta] = []
    var memories: [MemoryEntry] = []
    var created: [(content: String, container: String?)] = []
    func documentsList(container: String?) async throws -> [DocumentMeta] { documents }
    func listMemories(container: String?) async throws -> [MemoryEntry] { memories }
    func createMemory(content: String, isStatic: Bool, forgetAfter: String?, container: String?) async throws -> String {
        created.append((content, container))
        return "profile-memory"
    }
    func supersedeMemory(id: String, newContent: String, container: String?) async throws -> String { id }
    func forgetMemory(id: String, reason: String, container: String?) async throws {}
}

private actor StarterProfileTestFiles: StarterProfileFileAccess {
    var listed: [StarterProfileCandidate]
    var textByPath: [String: String]
    var candidateCalls = 0
    var requestedRoots: [URL] = []
    var readPaths: [String] = []
    init(listed: [StarterProfileCandidate] = [], textByPath: [String: String] = [:]) {
        self.listed = listed
        self.textByPath = textByPath
    }
    func candidates(in roots: [URL], limits: StarterProfileLimits) async throws -> [StarterProfileCandidate] {
        candidateCalls += 1
        requestedRoots = roots
        return listed
    }
    func extractText(from candidate: StarterProfileCandidate, maximumBytes: Int) async throws -> String? {
        readPaths.append(candidate.url.path)
        return textByPath[candidate.url.path]
    }
}

private actor StarterProfileTestUploader: CorpusFileUploading {
    var calls: [(path: String, container: String?)] = []
    func uploadFile(_ fileURL: URL, container: String?, metadata: [String: String]) async throws -> String {
        calls.append((fileURL.path, container))
        return "doc-\(calls.count)"
    }
}

private struct CancellingStarterProfileUploader: CorpusFileUploading {
    func uploadFile(_ fileURL: URL, container: String?, metadata: [String: String]) async throws -> String {
        throw CancellationError()
    }
}

private actor StarterProfileTestGenerator: Generating {
    var prompts: [String] = []
    var output = "- Works on local macOS software.\n- Keeps project notes in Documents."
    nonisolated func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.record(prompt)
                let output = await self.output
                continuation.yield(output)
                continuation.finish()
            }
        }
    }
    private func record(_ prompt: String) { prompts.append(prompt) }
}

private actor CancellingStarterProfileFiles: StarterProfileFileAccess {
    let candidate: StarterProfileCandidate
    init(candidate: StarterProfileCandidate) { self.candidate = candidate }
    func candidates(in roots: [URL], limits: StarterProfileLimits) async throws -> [StarterProfileCandidate] {
        [candidate]
    }
    func extractText(from candidate: StarterProfileCandidate, maximumBytes: Int) async throws -> String? {
        throw CancellationError()
    }
}

final class StarterProfileOnboardingTests: XCTestCase {
    private func candidate(_ name: String, bytes: Int, age: TimeInterval = 0) -> StarterProfileCandidate {
        StarterProfileCandidate(
            url: URL(fileURLWithPath: "/Users/test/Documents/\(name)"),
            byteCount: bytes,
            modifiedAt: Date(timeIntervalSince1970: 10_000 - age)
        )
    }
    func testEligibilityOnEmptyContainerDoesNotEnumerateOrReadUserFiles() async throws {
        let corpus = StarterProfileTestCorpus()
        let files = StarterProfileTestFiles()
        let service = StarterProfileOnboardingService(
            corpus: corpus,
            uploader: StarterProfileTestUploader(),
            generator: StarterProfileTestGenerator(),
            files: files,
            preferences: StarterProfileTestPreferences(),
            container: "mnemo"
        )
        let eligibility = try await service.eligibility()
        let candidateCalls = await files.candidateCalls
        let readPaths = await files.readPaths
        XCTAssertEqual(eligibility, .offer)
        XCTAssertEqual(candidateCalls, 0)
        XCTAssertEqual(readPaths, [])
    }

    func testEligibilityRequiresGenuinelyEmptyMnemoContainer() async throws {
        let corpus = StarterProfileTestCorpus()
        await corpus.setDocuments([
            DocumentMeta(id: "existing", filepath: nil, title: "Existing", status: "done",
                         containerTags: ["mnemo"], summary: nil, updatedAt: nil)
        ])
        let service = StarterProfileOnboardingService(
            corpus: corpus,
            uploader: StarterProfileTestUploader(),
            generator: StarterProfileTestGenerator(),
            files: StarterProfileTestFiles(),
            preferences: StarterProfileTestPreferences(),
            container: "mnemo"
        )
        let eligibility = try await service.eligibility()
        XCTAssertEqual(eligibility, .hidden)
    }

    func testSkippedOnboardingPersistsAndSuppressesFutureOffer() async throws {
        let preferences = StarterProfileTestPreferences()
        let service = StarterProfileOnboardingService(
            corpus: StarterProfileTestCorpus(),
            uploader: StarterProfileTestUploader(),
            generator: StarterProfileTestGenerator(),
            files: StarterProfileTestFiles(),
            preferences: preferences,
            container: "mnemo"
        )
        await service.skip()
        let preference = await preferences.load()
        let eligibility = try await service.eligibility()
        XCTAssertEqual(preference, .skipped)
        XCTAssertEqual(eligibility, .hidden)
    }

    func testOnlyExplicitlySelectedFoldersAreEnumerated() async throws {
        let file = candidate("selected.md", bytes: 40)
        let files = StarterProfileTestFiles(
            listed: [file], textByPath: [file.url.path: "I build local macOS applications."]
        )
        let service = StarterProfileOnboardingService(
            corpus: StarterProfileTestCorpus(),
            uploader: StarterProfileTestUploader(),
            generator: StarterProfileTestGenerator(),
            files: files,
            preferences: StarterProfileTestPreferences(),
            container: "mnemo"
        )

        _ = try await service.build(from: [.documents], homeDirectory: URL(fileURLWithPath: "/Users/test")) { _ in }
        let roots = await files.requestedRoots.map(\.path)

        XCTAssertEqual(roots, ["/Users/test/Documents"])
        XCTAssertFalse(roots.contains("/Users/test/Desktop"))
        XCTAssertFalse(roots.contains("/Users/test/Downloads"))
    }

    func testBuildHonorsFileByteAndContextCaps() async throws {
        let a = candidate("new.md", bytes: 80)
        let b = candidate("older.txt", bytes: 70, age: 10)
        let c = candidate("small.md", bytes: 40, age: 20)
        let tooLarge = candidate("huge.pdf", bytes: 151, age: 30)
        let files = StarterProfileTestFiles(
            listed: [c, tooLarge, b, a],
            textByPath: [
                a.url.path: String(repeating: "a", count: 80),
                b.url.path: String(repeating: "b", count: 70),
                c.url.path: String(repeating: "c", count: 40),
                tooLarge.url.path: "must not be read",
            ]
        )
        let limits = StarterProfileLimits(maxFiles: 2, maxFileBytes: 150,
                                          maxTotalBytes: 150, maxContextCharacters: 160,
                                          maxEnumeratedEntries: 100)
        let service = StarterProfileOnboardingService(
            corpus: StarterProfileTestCorpus(),
            uploader: StarterProfileTestUploader(),
            generator: StarterProfileTestGenerator(),
            files: files,
            preferences: StarterProfileTestPreferences(),
            container: "mnemo",
            limits: limits
        )

        let result = try await service.build(from: [.documents], homeDirectory: URL(fileURLWithPath: "/Users/test")) { _ in }
        let readPaths = await files.readPaths

        XCTAssertEqual(readPaths, [a.url.path, b.url.path])
        XCTAssertEqual(result.sampledFiles.count, 2)
        XCTAssertLessThanOrEqual(result.consumedBytes, limits.maxTotalBytes)
        XCTAssertLessThanOrEqual(result.contextCharacters, limits.maxContextCharacters)
    }

    func testBuildWritesSourcesAndProfileIntoSameMnemoContainer() async throws {
        let file = candidate("profile.md", bytes: 64)
        let corpus = StarterProfileTestCorpus()
        let uploader = StarterProfileTestUploader()
        let preferences = StarterProfileTestPreferences()
        let service = StarterProfileOnboardingService(
            corpus: corpus,
            uploader: uploader,
            generator: StarterProfileTestGenerator(),
            files: StarterProfileTestFiles(listed: [file], textByPath: [file.url.path: "I build Swift apps locally."]),
            preferences: preferences,
            container: "mnemo"
        )

        let result = try await service.build(from: [.documents], homeDirectory: URL(fileURLWithPath: "/Users/test")) { _ in }
        let uploadContainers = await uploader.calls.map(\.container)
        let memoryContainers = await corpus.created.map(\.container)
        let preference = await preferences.load()

        XCTAssertFalse(result.profile.isEmpty)
        XCTAssertEqual(uploadContainers, ["mnemo"])
        XCTAssertEqual(memoryContainers, ["mnemo"])
        XCTAssertEqual(preference, .completed)
    }

    func testNoReadableFilesProducesRenderableTerminalFailure() async throws {
        let service = StarterProfileOnboardingService(
            corpus: StarterProfileTestCorpus(),
            uploader: StarterProfileTestUploader(),
            generator: StarterProfileTestGenerator(),
            files: StarterProfileTestFiles(),
            preferences: StarterProfileTestPreferences(),
            container: "mnemo"
        )

        do {
            _ = try await service.build(from: [.documents], homeDirectory: URL(fileURLWithPath: "/Users/test")) { _ in }
            XCTFail("Expected a terminal failure")
        } catch let error as StarterProfileError {
            XCTAssertEqual(error, .noReadableFiles)
            XCTAssertFalse(StarterProfilePresentation.message(for: error).isEmpty)
        }
    }

    func testCredentialsAreRedactedBeforeGenerationAndBeforeMemoryWrite() async throws {
        let file = candidate("secrets.md", bytes: 90)
        let corpus = StarterProfileTestCorpus()
        let generator = StarterProfileTestGenerator()
        await generator.setOutput("- Uses Swift. password=hunter2 and sk-abcdefghijklmnop")
        let service = StarterProfileOnboardingService(
            corpus: corpus,
            uploader: StarterProfileTestUploader(),
            generator: generator,
            files: StarterProfileTestFiles(
                listed: [file],
                textByPath: [file.url.path: "Project notes. OPENAI_API_KEY=\"super secret value\" Bearer abcdefghijklmnop"]
            ),
            preferences: StarterProfileTestPreferences(),
            container: "mnemo"
        )

        let result = try await service.build(from: [.documents], homeDirectory: URL(fileURLWithPath: "/Users/test")) { _ in }
        let prompt = await generator.prompts.joined()
        let saved = await corpus.created.map(\.content).joined()

        XCTAssertFalse(prompt.contains("super secret value"))
        XCTAssertFalse(prompt.contains("abcdefghijklmnop"))
        XCTAssertFalse(result.profile.contains("hunter2"))
        XCTAssertFalse(saved.contains("hunter2"))
        XCTAssertTrue(result.profile.contains("[REDACTED]"))
    }

    func testCancellationDuringReadNeverPersistsProfileOrCompletion() async throws {
        let file = candidate("cancel.md", bytes: 40)
        let corpus = StarterProfileTestCorpus()
        let preferences = StarterProfileTestPreferences()
        let service = StarterProfileOnboardingService(
            corpus: corpus,
            uploader: StarterProfileTestUploader(),
            generator: StarterProfileTestGenerator(),
            files: CancellingStarterProfileFiles(candidate: file),
            preferences: preferences,
            container: "mnemo"
        )

        do {
            _ = try await service.build(from: [.documents], homeDirectory: URL(fileURLWithPath: "/Users/test")) { _ in }
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        let saved = await corpus.created
        let preference = await preferences.load()

        XCTAssertTrue(saved.isEmpty)
        XCTAssertEqual(preference, .pending)
    }

    func testCancellationDuringUploadNeverPersistsProfileOrCompletion() async throws {
        let file = candidate("cancel-upload.md", bytes: 40)
        let corpus = StarterProfileTestCorpus()
        let preferences = StarterProfileTestPreferences()
        let service = StarterProfileOnboardingService(
            corpus: corpus,
            uploader: CancellingStarterProfileUploader(),
            generator: StarterProfileTestGenerator(),
            files: StarterProfileTestFiles(
                listed: [file], textByPath: [file.url.path: "I work on local Swift applications."]
            ),
            preferences: preferences,
            container: "mnemo"
        )

        do {
            _ = try await service.build(from: [.documents], homeDirectory: URL(fileURLWithPath: "/Users/test")) { _ in }
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        let saved = await corpus.created
        let preference = await preferences.load()

        XCTAssertTrue(saved.isEmpty)
        XCTAssertEqual(preference, .pending)
    }

    func testLateSkipCannotBeOverwrittenByQueuedCompletion() async throws {
        let file = candidate("late-cancel.md", bytes: 40)
        let preferences = LateCancelStarterProfilePreferences()
        let service = StarterProfileOnboardingService(
            corpus: StarterProfileTestCorpus(),
            uploader: StarterProfileTestUploader(),
            generator: StarterProfileTestGenerator(),
            files: StarterProfileTestFiles(
                listed: [file], textByPath: [file.url.path: "I build local Swift applications."]
            ),
            preferences: preferences,
            container: "mnemo"
        )
        let build = Task {
            try await service.build(from: [.documents], homeDirectory: URL(fileURLWithPath: "/Users/test")) { _ in }
        }

        await preferences.waitForCompletionAttempt()
        build.cancel()
        await service.skip()
        await preferences.releaseCompletion()
        do {
            _ = try await build.value
            XCTFail("Expected late completion to observe cancellation")
        } catch is CancellationError {}
        let preference = await preferences.load()

        XCTAssertEqual(preference, .skipped)
    }
}

private extension StarterProfileTestCorpus {
    func setDocuments(_ value: [DocumentMeta]) { documents = value }
}

private extension StarterProfileTestGenerator {
    func setOutput(_ value: String) { output = value }
}
