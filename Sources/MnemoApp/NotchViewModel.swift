import AppKit
import SwiftUI
import MnemoOrchestrator

/// Command/recovery side-effects the view-model delegates to (implemented by
/// NotchController, which owns the engine, supervisor, and inspector).
@MainActor
protocol CommandHandling: AnyObject {
    func profileText() async -> String
    func forget(_ fact: String) async
    func recover(_ recovery: TerminalState.Recovery) async -> RecoveryOutcome?
    func openMemoryFolder()
    func preferencesText() async -> String
    func entityPanelText(_ name: String) async -> String
    func digestText() async -> String
}

struct RecoveryOutcome: Equatable, Sendable {
    let message: String
    let stackReady: Bool
}

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var state = NotchState(phase: .idle, query: "", answer: "", sources: [])
    @Published var privacy: PrivacyIndicator = .clean
    @Published private(set) var stackReadiness: StackReadiness = .starting
    @Published private(set) var volumeActivities: [VolumeID: VolumeIndexingActivity] = [:]
    @Published private(set) var permissionOnboardingState: PermissionOnboardingScreenState = .hidden
    @Published private(set) var permissionOnboardingPresented = false
    @Published private(set) var starterProfileState: StarterProfileScreenState = .hidden
    @Published private(set) var starterProfilePresented = false
    @Published private(set) var selectedStarterProfileSources: Set<StarterProfileSource> = []

    enum StackReadiness: Equatable { case starting, ready, failed }
    var inputPlaceholder: String {
        switch stackReadiness {
        case .starting: "Starting local engine…"
        case .ready: "Ask Mnemo"
        case .failed: "Local engine unavailable"
        }
    }

    var volumeActivityText: String? {
        guard let volumeActivity = foregroundVolumeActivity else { return nil }
        let name = volumeActivity.volume.name
        let otherCount = max(0, volumeActivities.count - 1)
        let suffix = otherCount > 0 ? " · +\(otherCount) drive\(otherCount == 1 ? "" : "s")" : ""
        switch volumeActivity {
        case .detected:
            return "External drive found: \(name)\(suffix)"
        case .scanning:
            return "Scanning \(name) locally…\(suffix)"
        case .indexing(_, let uploaded, _, let deleted, let deferred):
            let changed = uploaded + deleted
            return deferred > 0
                ? "Indexing \(name) · \(changed) changed · \(deferred) queued\(suffix)"
                : "Indexing \(name) · \(changed) changed\(suffix)"
        case .ready(_, let indexed):
            return "\(name) ready · \(indexed) files indexed\(suffix)"
        case .error:
            return "Couldn't index \(name) completely on-device\(suffix)"
        case .unmounted, .cancelled:
            return nil
        }
    }

    var volumeActivityPreventsAutoCollapse: Bool {
        volumeActivities.values.contains { activity in
            switch activity.phase {
            case .detected, .scanning, .indexing, .ready: true
            case .error, .unmounted, .cancelled: false
            }
        }
    }

    private var foregroundVolumeActivity: VolumeIndexingActivity? {
        volumeActivities.values.sorted { lhs, rhs in
            let left = Self.volumeActivityPriority(lhs.phase)
            let right = Self.volumeActivityPriority(rhs.phase)
            if left != right { return left > right }
            return lhs.volume.name.localizedCaseInsensitiveCompare(rhs.volume.name) == .orderedAscending
        }.first
    }

    private static func volumeActivityPriority(_ phase: VolumeActivityPhase) -> Int {
        switch phase {
        case .indexing: 6
        case .scanning: 5
        case .detected: 4
        case .error: 3
        case .ready: 2
        case .unmounted, .cancelled: 0
        }
    }

    private let makeService: (String, ResponseTone) -> QueryServing   // (container, tone) → service
    private let scheduler: WorkScheduler?
    private let egressCounter: () -> Int
    private let permissionAuthorizer: PermissionAuthorizing?
    private let permissionPreferenceStore: PermissionOnboardingPreferenceStoring?
    private let starterProfileService: StarterProfileOnboardingService?
    private weak var commands: CommandHandling?
    /// Thumbs-up wiring (UI.md §8): strengthens the cited memories.
    var onFeedback: (([SourceCard]) -> Void)?
    /// Controller-owned services that must start after either initial stack
    /// startup or a successful recovery.
    var onStackReady: (() -> Void)?

    private var activeContainer: String
    private var history = QueryHistory(cap: 50)
    private var lastQuery = ""
    private var tone: ResponseTone
    private var activeQueryTask: Task<Void, Never>?
    private var volumeActivityClearTasks: [VolumeID: Task<Void, Never>] = [:]
    private var queryGeneration = 0
    private var permissionOnboardingGeneration = 0
    private var permissionOnboardingTask: Task<Void, Never>?
    private var starterProfileGeneration = 0
    private var starterProfileTask: Task<Void, Never>?

    /// True while a query is streaming. Used to lock out re-summon and
    /// mouse-leave dismissal so a hover-out/in during an in-flight answer can't
    /// tear down and re-open the surface as a duplicate session.
    private var runningQueries = 0
    var isQuerying: Bool { runningQueries > 0 }

    init(defaultContainer: String = "mnemo",
         tone: ResponseTone = .balanced,
         makeService: @escaping (String, ResponseTone) -> QueryServing,
         scheduler: WorkScheduler? = nil,
         commands: CommandHandling? = nil,
         permissionAuthorizer: PermissionAuthorizing? = nil,
         permissionPreferenceStore: PermissionOnboardingPreferenceStoring? = nil,
         starterProfileService: StarterProfileOnboardingService? = nil,
         egressCounter: @escaping () -> Int = { LoopbackGuardURLProtocol.blockedCount }) {
        self.activeContainer = defaultContainer
        self.tone = tone
        self.makeService = makeService
        self.scheduler = scheduler
        self.commands = commands
        self.permissionAuthorizer = permissionAuthorizer
        self.permissionPreferenceStore = permissionPreferenceStore
        self.starterProfileService = starterProfileService
        self.egressCounter = egressCounter
    }

    func setCommands(_ c: CommandHandling) { self.commands = c }

    // MARK: - Session lifecycle

    func summon() {
        // Single chokepoint for every summon path (hover, hotkey, tap): never
        // open a fresh session while a query is still streaming, else a stray
        // summon spawns a duplicate over the in-flight answer.
        guard !isQuerying else { return }
        if stackReadiness == .failed {
            state = NotchState(
                phase: .state,
                query: "",
                answer: "",
                sources: [],
                terminal: .engineUnreachable
            )
            return
        }
        if permissionOnboardingState.isAvailable {
            permissionOnboardingPresented = true
            state.phase = .answering
            refreshPrivacy()
            return
        }
        if starterProfileState.isAvailable {
            starterProfilePresented = true
            state.phase = .answering
            refreshPrivacy()
            return
        }
        state = NotchState(phase: .input, query: "", answer: "", sources: [])
        refreshPrivacy()
        // Proactive digest (beats-Siri #5): surface what changed, quietly, as
        // the status line — never blocking input.
        let generation = queryGeneration
        Task { [weak self] in
            guard let self, let digest = await self.commands?.digestText(), !digest.isEmpty else { return }
            guard self.isCurrent(generation) else { return }
            if self.state.phase == .input && self.state.answer.isEmpty && self.state.query.isEmpty {
                self.state.status = digest
            }
        }
    }
    func dismiss() {
        invalidateActiveQuery()
        if starterProfileTask != nil {
            starterProfileGeneration &+= 1
            starterProfileTask?.cancel()
            starterProfileTask = nil
            starterProfileState = .consent
        }
        permissionOnboardingPresented = false
        starterProfilePresented = false
        state.phase = .idle
    }

    func stackDidStart() {
        let becameReady = stackReadiness != .ready
        stackReadiness = .ready
        if becameReady { onStackReady?() }
    }

    func stackDidFail() {
        stackReadiness = .failed
        guard !showsPermissionOnboarding else { return }
        guard state.phase != .idle, !isQuerying else { return }
        state = NotchState(
            phase: .state,
            query: state.query,
            answer: "",
            sources: [],
            terminal: .engineUnreachable
        )
    }

    // MARK: - Permission onboarding

    @discardableResult
    func offerPermissionOnboardingIfNeeded() async -> Bool {
        guard let permissionAuthorizer, let permissionPreferenceStore,
              permissionOnboardingState == .hidden
        else { return false }
        let preference = await permissionPreferenceStore.load()
        let snapshot = permissionAuthorizer.snapshot()
        guard PermissionOnboardingPolicy.shouldOffer(
            preference: preference,
            snapshot: snapshot
        ) else { return false }
        permissionOnboardingState = .ready(snapshot)
        permissionOnboardingPresented = true
        starterProfilePresented = false
        state.phase = .answering
        refreshPrivacy()
        return true
    }

    var showsPermissionOnboarding: Bool {
        permissionOnboardingPresented && permissionOnboardingState.isAvailable
    }

    func requestVoicePermissions() {
        guard let permissionAuthorizer,
              permissionOnboardingTask == nil,
              let snapshot = permissionOnboardingState.snapshot
        else { return }
        permissionOnboardingGeneration &+= 1
        let generation = permissionOnboardingGeneration
        permissionOnboardingState = .requesting(snapshot)
        permissionOnboardingTask = Task { [weak self] in
            guard let self else { return }
            let updated = await permissionAuthorizer.requestVoicePermissions()
            guard self.permissionOnboardingGeneration == generation else { return }
            self.permissionOnboardingState = .ready(updated)
            self.permissionOnboardingTask = nil
        }
    }

    func refreshPermissionOnboarding() {
        guard let permissionAuthorizer, permissionOnboardingState.isAvailable,
              permissionOnboardingTask == nil
        else { return }
        permissionOnboardingState = .ready(permissionAuthorizer.snapshot())
    }

    func openPermissionSettings(_ permission: PermissionKind) {
        permissionAuthorizer?.openSystemSettings(for: permission)
    }

    func finishPermissionOnboarding() {
        guard let permissionPreferenceStore,
              permissionOnboardingTask == nil,
              let snapshot = permissionOnboardingState.snapshot,
              PermissionOnboardingPolicy.canComplete(snapshot)
        else { return }
        permissionOnboardingGeneration &+= 1
        let generation = permissionOnboardingGeneration
        permissionOnboardingTask = Task { [weak self] in
            guard let self else { return }
            let preference = await permissionPreferenceStore.transition(to: .completed)
            guard self.permissionOnboardingGeneration == generation,
                  preference == .completed else { return }
            self.permissionOnboardingTask = nil
            self.permissionOnboardingState = .hidden
            self.permissionOnboardingPresented = false
            self.state = NotchState(phase: .input, query: "", answer: "", sources: [])
            _ = await self.offerStarterProfileAfterPermissions()
        }
    }

    @discardableResult
    func offerStarterProfileAfterPermissions() async -> Bool {
        guard stackReadiness == .ready else { return false }
        return await offerStarterProfileIfNeeded()
    }

    /// Checks engine metadata only. User-folder enumeration does not begin
    /// until `startStarterProfile`, after the source toggles are confirmed.
    @discardableResult
    func offerStarterProfileIfNeeded() async -> Bool {
        guard !permissionOnboardingState.isAvailable else { return false }
        guard let starterProfileService, starterProfileState == .hidden else { return false }
        guard (try? await starterProfileService.eligibility()) == .offer else { return false }
        starterProfileState = .consent
        guard (state.phase == .idle || state.phase == .input), !isQuerying else { return false }
        starterProfilePresented = true
        state.phase = .answering
        refreshPrivacy()
        return true
    }

    var showsStarterProfile: Bool {
        starterProfilePresented && starterProfileState.isAvailable
    }

    func setStarterProfileSource(_ source: StarterProfileSource, selected: Bool) {
        guard starterProfileTask == nil else { return }
        if selected { selectedStarterProfileSources.insert(source) }
        else { selectedStarterProfileSources.remove(source) }
    }

    func startStarterProfile() {
        guard let starterProfileService, starterProfileTask == nil,
              !selectedStarterProfileSources.isEmpty else { return }
        starterProfileGeneration &+= 1
        let generation = starterProfileGeneration
        let sources = selectedStarterProfileSources
        starterProfilePresented = true
        starterProfileState = .building(.findingFiles)
        state.phase = .answering

        starterProfileTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await starterProfileService.build(
                    from: sources,
                    homeDirectory: FileManager.default.homeDirectoryForCurrentUser
                ) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self, self.starterProfileGeneration == generation else { return }
                        self.starterProfileState = .building(progress)
                    }
                }
                guard starterProfileGeneration == generation else { return }
                starterProfileState = .review(result)
            } catch is CancellationError {
                guard starterProfileGeneration == generation else { return }
                starterProfileState = .consent
            } catch let error as StarterProfileError {
                guard starterProfileGeneration == generation else { return }
                starterProfileState = .failed(StarterProfilePresentation.message(for: error))
            } catch {
                guard starterProfileGeneration == generation else { return }
                starterProfileState = .failed("The starter profile couldn't be created on-device.")
            }
            if starterProfileGeneration == generation { starterProfileTask = nil }
        }
    }

    func retryStarterProfile() { startStarterProfile() }

    func skipStarterProfile() {
        starterProfileGeneration &+= 1
        starterProfileTask?.cancel()
        starterProfileTask = nil
        starterProfileState = .hidden
        starterProfilePresented = false
        state = NotchState(phase: .input, query: "", answer: "", sources: [])
        guard let starterProfileService else { return }
        Task(priority: .utility) { await starterProfileService.skip() }
    }

    func finishStarterProfileReview() {
        starterProfileTask = nil
        starterProfileState = .hidden
        starterProfilePresented = false
        state = NotchState(phase: .input, query: "", answer: "", sources: [])
    }

    func updateVolumeActivity(_ activity: VolumeIndexingActivity) {
        guard let id = activity.volume.id else { return }
        volumeActivityClearTasks[id]?.cancel()
        if activity.phase == .unmounted || activity.phase == .cancelled {
            volumeActivities.removeValue(forKey: id)
            volumeActivityClearTasks.removeValue(forKey: id)
            return
        }
        volumeActivities[id] = activity
        if activity.phase == .detected, state.phase == .idle {
            state = NotchState(phase: .input, query: "", answer: "", sources: [])
            refreshPrivacy()
        }
        guard activity.phase == .ready else { return }
        volumeActivityClearTasks[id] = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(6))
            } catch {
                return
            }
            guard let self, self.volumeActivities[id] == activity else { return }
            self.volumeActivities.removeValue(forKey: id)
            self.volumeActivityClearTasks.removeValue(forKey: id)
        }
    }

    /// /clear or Cmd+K — fresh conversation, history preserved for recall.
    func newConversation() {
        invalidateActiveQuery()
        state = NotchState(phase: .input, query: "", answer: "", sources: [])
    }

    // MARK: - Submit / commands

    /// Own the submission task so dismiss and the visible cancel control can
    /// stop real work instead of merely hiding the spinner.
    func beginSubmit() {
        beginOwnedOperation { viewModel, generation in
            await viewModel.submit(generation: generation)
        }
    }

    func submitSuggestion(_ suggestion: String) {
        let query = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, activeQueryTask == nil else { return }
        state.query = query
        beginSubmit()
    }

    func beginRecovery(_ recovery: TerminalState.Recovery) {
        beginOwnedOperation { viewModel, generation in
            await viewModel.recover(recovery, generation: generation)
        }
    }

    private func beginOwnedOperation(
        _ operation: @escaping @MainActor (NotchViewModel, Int) async -> Void
    ) {
        guard activeQueryTask == nil else { return }
        queryGeneration &+= 1
        let generation = queryGeneration
        activeQueryTask = Task { [weak self] in
            guard let self else { return }
            await operation(self, generation)
            if self.queryGeneration == generation {
                self.activeQueryTask = nil
            }
        }
    }

    func cancelQuery() {
        guard activeQueryTask != nil || isQuerying else { return }
        invalidateActiveQuery()
        state = NotchInteraction.cancelledState(state)
        refreshPrivacy()
    }

    private func invalidateActiveQuery() {
        queryGeneration &+= 1
        activeQueryTask?.cancel()
        activeQueryTask = nil
    }

    private func submit(generation: Int) async {
        let raw = state.query
        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        // A query is already in flight — drop repeat submits so a second message
        // can't be fired while the first is still working (the surface stays in
        // its working/searching state until the answer arrives).
        guard state.phase != .searching else { return }
        switch CommandParser.parse(raw) {
        case .command(let command): await handle(command, generation: generation)
        case .query(let q):
            // Metacognition (beats-Siri #8): "how sure are you?" is answered
            // honestly from the measured grounding of the last answer.
            if ConfidenceReport.isMetaQuestion(q), !state.answer.isEmpty {
                showInfo(ConfidenceReport.report(state.overallConfidence, sourceCount: state.sources.count))
            } else {
                await runQuery(q, generation: generation)
            }
        }
    }

    private func handle(_ command: Command, generation: Int) async {
        guard isCurrent(generation) else { return }
        switch command {
        case .help:
            showInfo(CommandParser.helpText)
        case .clear:
            newConversation()
        case .inspect, .profile:
            showInfo("Gathering your profile…")
            let text = await commands?.profileText() ?? "No profile available."
            guard isCurrent(generation) else { return }
            showInfo(text)
        case .forget(let fact):
            await commands?.forget(fact)
            guard isCurrent(generation) else { return }
            showInfo("Forgotten: “\(fact)”. It won't come back even if its source is re-read.")
        case .scope(let container):
            activeContainer = container
            showInfo("Now answering from the “\(container)” scope.")
        case .tone(let raw):
            if let t = ResponseTone(rawValue: raw) {
                tone = t
                showInfo("Tone set to \(t.rawValue). Answers will be \(t == .brief ? "shorter" : t == .detailed ? "more thorough" : "balanced").")
            } else {
                showInfo("Unknown tone “\(raw)”. Try: brief, balanced, or detailed.")
            }
        case .more:
            await goDeeper(generation: generation)
        case .why:
            // Provenance chain (beats-Siri #7): claim → source for the last answer.
            if state.answer.isEmpty {
                showInfo("Ask something first — then /why shows where each claim came from.")
            } else {
                let verdicts = Provenance.fromAnswer(state.answer,
                                                     unsupported: state.unsupportedSentences,
                                                     sources: state.sources)
                showInfo(Provenance.explain(verdicts))
            }
        case .entity(let name):
            showInfo("Gathering what I know about \(name)…")
            let text = await commands?.entityPanelText(name) ?? "Couldn't build the panel right now."
            guard isCurrent(generation) else { return }
            showInfo(text)
        case .preferences:
            showInfo("Reading the model of you…")
            let text = await commands?.preferencesText() ?? "No preferences learned yet."
            guard isCurrent(generation) else { return }
            showInfo(text)
        }
    }

    /// Go deeper (#9): re-ask the last question at a more thorough tone.
    func goDeeper(generation: Int? = nil) async {
        guard !lastQuery.isEmpty else { showInfo("Ask something first, then /more digs deeper."); return }
        let previousTone = tone
        tone = .detailed
        await runQuery(lastQuery, generation: generation)
        tone = previousTone
    }

    /// Copy the answer + citations as Markdown (#6).
    func exportAnswer() {
        guard !state.answer.isEmpty else { return }
        let md = AnswerExport.markdown(question: lastQuery.isEmpty ? state.query : lastQuery,
                                       answer: state.answer, sources: state.sources)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)
    }

    private func runQuery(_ q: String, generation: Int? = nil) async {
        guard generation.map(isCurrent) ?? !Task.isCancelled else { return }
        rememberHistory(q)
        lastQuery = q
        state.query = q
        state.answer = ""
        state.sources = []
        state.terminal = nil
        state.unsupportedSentences = []
        state.phase = .searching
        state.status = "Searching your memory…"

        runningQueries += 1
        defer { runningQueries -= 1 }

        let token = await scheduler?.beginInteractive()
        defer { if let token { Task { await scheduler?.endInteractive(token) } } }

        do {
            for try await event in makeService(activeContainer, tone).ask(q) {
                try Task.checkCancellation()
                guard generation.map(isCurrent) ?? !Task.isCancelled else { return }
                state = NotchReducer.apply(event, to: state)
            }
        } catch is CancellationError {
            return
        } catch {
            guard generation.map(isCurrent) ?? !Task.isCancelled else { return }
            state.phase = .state
            state.terminal = .engineUnreachable
            state.status = ""
        }
        if generation.map(isCurrent) ?? !Task.isCancelled { refreshPrivacy() }
    }

    /// Recovery-button actions actually do something (not no-ops).
    private func recover(_ recovery: TerminalState.Recovery, generation: Int) async {
        guard isCurrent(generation) else { return }
        switch recovery {
        case .broaden, .waitAndRetry:
            if !lastQuery.isEmpty { await runQuery(lastQuery, generation: generation) }
        case .addFiles:
            commands?.openMemoryFolder()
        case .restartEngine, .loadModel:
            let previous = lastQuery
            showInfo(recovery == .restartEngine ? "Restarting the engine…" : "Loading the model…")
            let result = await commands?.recover(recovery)
            guard isCurrent(generation) else { return }
            if let result {
                if result.stackReady { stackDidStart() }
                showInfo(result.message)
            }
            if !previous.isEmpty { await runQuery(previous, generation: generation) }
        }
    }

    // MARK: - History recall (Up/Down arrow)

    private func rememberHistory(_ q: String) { history.remember(q) }
    func recallPrevious() { if let q = history.previous() { state.query = q } }
    func recallNext() { if let q = history.next() { state.query = q } }

    // MARK: - Feedback (thumbs)

    /// Thumbs on the current answer: up strengthens every cited memory via the
    /// strength ledger; down just registers (never crashes, never blocks).
    func feedback(positive: Bool) {
        guard !state.answer.isEmpty else { return }
        state.feedback = positive
        if positive { onFeedback?(state.sources) }
    }

    // MARK: - Copy

    func copyAnswer() {
        guard !state.answer.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(state.answer, forType: .string)
    }

    // MARK: - Helpers

    /// Surface an informational message (e.g. a dictation error) in the notch —
    /// the input/listening states have no body space of their own, so route it
    /// through the answer block where it is actually visible.
    func presentInfo(_ text: String) { showInfo(text) }

    /// Render arbitrary informational text as if it were an answer block.
    private func showInfo(_ text: String) {
        state.phase = .answering
        state.terminal = nil
        state.status = ""
        state.sources = []
        state.answer = text
    }

    private func isCurrent(_ generation: Int) -> Bool {
        !Task.isCancelled && generation == queryGeneration
    }

    private func refreshPrivacy() {
        let observed = egressCounter()
        privacy = observed == 0 ? .clean : .egressDetected(count: observed)
    }
}
