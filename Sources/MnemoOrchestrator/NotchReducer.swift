/// Pure state reduction for the notch surface: QueryEvents in, view state out.
/// Invariant (A-028): constructs no network URLs — pure state machine only.
/// Kept in the orchestrator target so it is hermetically testable; the app's
/// view-model is a thin @MainActor wrapper around this.
public enum NotchPhase: Equatable, Sendable { case idle, input, searching, answering, state }

/// One completed question→answer exchange (conversation history).
public struct Turn: Equatable, Sendable {
    public let question: String
    public let answer: String
    public let sources: [SourceCard]
    public init(question: String, answer: String, sources: [SourceCard]) {
        self.question = question
        self.answer = answer
        self.sources = sources
    }
}

public struct NotchState: Equatable, Sendable {
    public var phase: NotchPhase
    public var query: String
    public var answer: String
    public var sources: [SourceCard]
    public var terminal: TerminalState?
    public var unsupportedSentences: Set<Int>   // M5 flags (rendered distinct)
    public var status: String                   // live "Searching…/Reading…" label
    public var transcript: [Turn]               // prior turns (follow-up conversation)
    public var understanding: String            // "Reading across 3 notes…" (#3)
    public var suggestions: [String]            // expressive follow-up chips (#6)
    public var related: [SourceCard]            // see-also documents (#8)
    public var entities: [String]              // salient entities to explore (intelligence #8)
    public var reasoning: [String]             // visible reasoning steps (beats-Siri #1)
    public var feedback: Bool? = nil           // thumbs up/down on the current answer
    public init(phase: NotchPhase, query: String, answer: String, sources: [SourceCard],
                terminal: TerminalState? = nil, unsupportedSentences: Set<Int> = [],
                status: String = "", transcript: [Turn] = [],
                understanding: String = "", suggestions: [String] = [], related: [SourceCard] = [],
                entities: [String] = [], reasoning: [String] = []) {
        self.phase = phase
        self.query = query
        self.answer = answer
        self.sources = sources
        self.terminal = terminal
        self.unsupportedSentences = unsupportedSentences
        self.status = status
        self.transcript = transcript
        self.understanding = understanding
        self.suggestions = suggestions
        self.related = related
        self.entities = entities
        self.reasoning = reasoning
    }

    /// Overall answer confidence from retrieval strength + grounding (#4/#10).
    public var overallConfidence: ConfidenceLevel {
        let topSim = sources.map(\.relevance).max() ?? 0
        let total = max(1, Sentences.split(answer).count)
        let supportedRatio = answer.isEmpty ? 0 : Double(total - unsupportedSentences.count) / Double(total)
        return Confidence.overall(topSimilarity: topSim, supportedRatio: supportedRatio)
    }
    /// Framing sentence shown above a grounded answer.
    public var confidenceFraming: String {
        answer.isEmpty ? "" : Confidence.framing(overallConfidence, sourceCount: sources.count)
    }
}

public enum NotchReducer {
    // A-288: intelligence
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

    // A-340: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-196: ingestion
    // MARK: - ingestion
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }



    // A-236: memory
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

    public static func apply(_ event: QueryEvent, to state: NotchState) -> NotchState {
        var s = state
        switch event {
        case .routed:
            // Start of a query: clear answer state but preserve routing reasoning.
            let priorReasoning = s.reasoning
            s.phase = .searching
            s.answer = ""
            s.sources = []
            s.terminal = nil
            s.unsupportedSentences = []
            s.status = "Searching your memory…"
            s.understanding = ""
            s.suggestions = []
            s.related = []
            s.entities = []
            s.reasoning = priorReasoning
            s.feedback = nil
        case .related(let docs):
            s.related = docs
        case .reasoning(let steps):
            s.reasoning.append(contentsOf: steps)
        case .entities(let ents):
            s.entities = ents
        case .retrying(let reason):
            // Self-correction (#3): discard the ungrounded draft and re-answer.
            s.answer = ""
            s.unsupportedSentences = []
            s.status = reason
            s.phase = .searching
        case .understanding(let phrase):
            s.understanding = phrase
            if s.answer.isEmpty { s.status = phrase }
        case .suggestions(let chips):
            s.suggestions = chips
        case .sources(let cards):
            s.sources = cards
            if s.answer.isEmpty && s.understanding.isEmpty { s.status = "Reading your files…" }
        case .token(let t):
            s.phase = .answering
            s.terminal = nil        // tokens supersede any earlier terminal state
            s.status = ""           // answer is streaming; no status label
            s.answer += t
        case .citation(let index, let supported): if !supported { s.unsupportedSentences.insert(index) }
        case .state(let terminal): s.phase = .state; s.terminal = terminal; s.status = ""
        case .done:
            // Record a completed answer as a conversation turn (follow-ups keep
            // prior turns). Non-answer outcomes (terminal states) aren't turns.
            if !s.answer.isEmpty && s.terminal == nil {
                s.transcript.append(Turn(question: s.query, answer: s.answer, sources: s.sources))
            }
        }
        return s
    }

    /// Every terminal state has a defined, rendered message (invariant 6).
    public static func message(for terminal: TerminalState) -> String {
        switch terminal {
        case .indexing(let path):
            return "Still indexing \((path as NSString).lastPathComponent) — ask again in a moment."
        case .empty:
            return "Nothing in your files matches that closely. Try broadening the question."
        case .emptyCorpus:
            return "No files yet. Drop documents into ~/Mnemo/memory to start — PDFs, notes, images, audio all work."
        case .modelNotLoaded(let model):
            return "The model \(model) isn't loaded. Load it to continue."
        case .engineUnreachable:
            return "The memory engine isn't responding. Restart it to continue."
        case .unsupportedAnswer:
            return "I couldn't ground an answer in your files, so I won't guess."
        }
    }
}

import Foundation
