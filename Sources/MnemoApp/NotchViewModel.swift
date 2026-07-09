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
    func dismiss() { state.phase = .idle }

    /// /clear or Cmd+K — fresh conversation, history preserved for recall.
    func newConversation() {
        state = NotchState(phase: .input, query: "", answer: "", sources: [])
    }

    // MARK: - Submit / commands

    func submit() async {
        let raw = state.query
        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        switch CommandParser.parse(raw) {
        case .command(let command): await handle(command)
        case .query(let q):
            // Metacognition (beats-Siri #8): "how sure are you?" is answered
            // honestly from the measured grounding of the last answer.
            if ConfidenceReport.isMetaQuestion(q), !state.answer.isEmpty {
                showInfo(ConfidenceReport.report(state.overallConfidence, sourceCount: state.sources.count))
            } else {
                await runQuery(q)
            }
        }
    }

    private func handle(_ command: Command) async {
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
            await goDeeper()
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
    func goDeeper() async {
        guard !lastQuery.isEmpty else { showInfo("Ask something first, then /more digs deeper."); return }
        let previousTone = tone
        tone = .detailed
        await runQuery(lastQuery)
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

    private func runQuery(_ q: String) async {
        rememberHistory(q)
        lastQuery = q
        state.query = q
        state.answer = ""
        state.sources = []
        state.terminal = nil
        state.unsupportedSentences = []
        state.phase = .searching
        state.status = "Searching your memory…"

        let token = await scheduler?.beginInteractive()
        defer { if let token { Task { await scheduler?.endInteractive(token) } } }

        do {
            for try await event in makeService(activeContainer, tone).ask(q) {
                state = NotchReducer.apply(event, to: state)
            }
        } catch {
            state.phase = .state
            state.terminal = .engineUnreachable
            state.status = ""
        }
        refreshPrivacy()
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
