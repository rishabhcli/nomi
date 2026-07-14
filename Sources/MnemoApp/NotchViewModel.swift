import AppKit
import SwiftUI
import MnemoOrchestrator

/// Command/recovery side-effects the view-model delegates to (implemented by
/// NotchController, which owns the engine, supervisor, and inspector).
@MainActor
protocol CommandHandling: AnyObject {
    func profileText() async -> String
    func forget(_ fact: String) async
    func recover(_ recovery: TerminalState.Recovery) async -> String?
    func openMemoryFolder()
    func preferencesText() async -> String
    func entityPanelText(_ name: String) async -> String
    func digestText() async -> String
}

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var state = NotchState(phase: .idle, query: "", answer: "", sources: [])
    @Published var privacy: PrivacyIndicator = .clean

    private let makeService: (String, ResponseTone) -> QueryServing   // (container, tone) → service
    private let scheduler: WorkScheduler?
    private weak var commands: CommandHandling?
    /// Thumbs-up wiring (UI.md §8): strengthens the cited memories.
    var onFeedback: (([SourceCard]) -> Void)?

    private var activeContainer: String
    private var history = QueryHistory(cap: 50)
    private var lastQuery = ""
    private var tone: ResponseTone
    private var activeQueryTask: Task<Void, Never>?
    private var queryGeneration = 0

    /// True while a query is streaming. Used to lock out re-summon and
    /// mouse-leave dismissal so a hover-out/in during an in-flight answer can't
    /// tear down and re-open the surface as a duplicate session.
    private var runningQueries = 0
    var isQuerying: Bool { runningQueries > 0 }

    init(defaultContainer: String = "mnemo",
         tone: ResponseTone = .balanced,
         makeService: @escaping (String, ResponseTone) -> QueryServing,
         scheduler: WorkScheduler? = nil,
         commands: CommandHandling? = nil) {
        self.activeContainer = defaultContainer
        self.tone = tone
        self.makeService = makeService
        self.scheduler = scheduler
        self.commands = commands
    }

    func setCommands(_ c: CommandHandling) { self.commands = c }

    // MARK: - Session lifecycle

    func summon() {
        // Single chokepoint for every summon path (hover, hotkey, tap): never
        // open a fresh session while a query is still streaming, else a stray
        // summon spawns a duplicate over the in-flight answer.
        guard !isQuerying else { return }
        state = NotchState(phase: .input, query: "", answer: "", sources: [])
        refreshPrivacy()
        // Proactive digest (beats-Siri #5): surface what changed, quietly, as
        // the status line — never blocking input.
        Task { [weak self] in
            guard let self, let digest = await self.commands?.digestText(), !digest.isEmpty else { return }
            if self.state.phase == .input && self.state.answer.isEmpty && self.state.query.isEmpty {
                self.state.status = digest
            }
        }
    }
    func dismiss() {
        invalidateActiveQuery()
        state.phase = .idle
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
        guard activeQueryTask == nil else { return }
        queryGeneration &+= 1
        let generation = queryGeneration
        activeQueryTask = Task { [weak self] in
            guard let self else { return }
            await self.submit(generation: generation)
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
        switch command {
        case .help:
            showInfo(CommandParser.helpText)
        case .clear:
            newConversation()
        case .inspect, .profile:
            showInfo("Gathering your profile…")
            let text = await commands?.profileText() ?? "No profile available."
            showInfo(text)
        case .forget(let fact):
            await commands?.forget(fact)
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
            showInfo(await commands?.entityPanelText(name) ?? "Couldn't build the panel right now.")
        case .preferences:
            showInfo("Reading the model of you…")
            showInfo(await commands?.preferencesText() ?? "No preferences learned yet.")
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
        guard generation.map({ $0 == queryGeneration }) ?? true else { return }
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
                guard generation.map({ $0 == queryGeneration }) ?? true else { return }
                state = NotchReducer.apply(event, to: state)
            }
        } catch is CancellationError {
            return
        } catch {
            guard generation.map({ $0 == queryGeneration }) ?? true else { return }
            state.phase = .state
            state.terminal = .engineUnreachable
            state.status = ""
        }
        if generation.map({ $0 == queryGeneration }) ?? true { refreshPrivacy() }
    }

    /// Recovery-button actions actually do something (not no-ops).
    func recover(_ recovery: TerminalState.Recovery) async {
        switch recovery {
        case .broaden, .waitAndRetry:
            if !lastQuery.isEmpty { await runQuery(lastQuery) }
        case .addFiles:
            commands?.openMemoryFolder()
        case .restartEngine, .loadModel:
            let previous = lastQuery
            showInfo(recovery == .restartEngine ? "Restarting the engine…" : "Loading the model…")
            let result = await commands?.recover(recovery)
            if let result { showInfo(result) }
            if !previous.isEmpty { await runQuery(previous) }   // auto-retry after recovery
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

    private func refreshPrivacy() {
        let blocked = LoopbackGuardURLProtocol.blockedCount
        privacy = blocked == 0 ? .clean : .egressDetected(count: blocked)
    }
}
