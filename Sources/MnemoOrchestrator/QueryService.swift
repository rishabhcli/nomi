import Foundation
import MnemoCore

// QueryService.swift — query lifecycle orchestrator (M4–M12).
// Public entry points:
//   QueryServing.ask(_:) / ask(_:history:) — AsyncThrowingStream<QueryEvent>
//   QueryService.init(...) — wires retriever, generator, router, verifier, cache
//   QueryService.ask — route → gather → assemble → generate → verify → done
//   SearchDefaults — retrieval knobs from mnemo.toml (mode, threshold, limit)
//   SourceCard — cited source metadata (title, path, snippet, relevance)
//   TerminalState — non-answer outcomes (indexing, empty, emptyCorpus, …)
//   TerminalState.recovery — one-tap recovery affordance per dead end
//   QueryEvent — streamed events (routed, understanding, sources, token, done)
//   NearestProbing — optional below-threshold nearest matches for empty path

public struct SourceCard: Equatable, Sendable {
    // A-053: beats-Siri gate — cross-doc offline synthesis with verified citations
    public let title, path, docId: String
    public let snippet: String?    // the quoted text that grounds the citation
    public let relevance: Double   // 0…1 similarity → drives the relevance bar
    public let updatedAt: String?  // ISO8601 of when the fact was last learned
    public init(title: String, path: String, docId: String, snippet: String? = nil,
                relevance: Double = 0, updatedAt: String? = nil) {
        self.title = title
        self.path = path
        self.docId = docId
        self.snippet = snippet
        self.relevance = relevance
        self.updatedAt = updatedAt
    }
    public var confidence: ConfidenceLevel { ConfidenceLevel.forSimilarity(relevance) }
}

/// Non-answer terminal states (PLAN.md M12 state machine). Every case is a
/// defined, rendered output — a query can never end in a silent empty screen.
public enum TerminalState: Equatable, Sendable {
    case indexing(path: String)      // best-matching file not ready yet (M2)
    case empty(nearest: [SourceCard])// nothing above threshold (M12)
    case emptyCorpus                 // no files ingested yet — first-run onboarding
    case modelNotLoaded(model: String)
    case engineUnreachable
    case unsupportedAnswer           // M5 flagged every sentence

    /// One-tap recovery affordance for each dead end.
    public enum Recovery: Equatable, Sendable {
        case waitAndRetry, broaden, loadModel, restartEngine, addFiles
    }
    public var recovery: Recovery {
        switch self {
        case .indexing: return .waitAndRetry
        case .empty, .unsupportedAnswer: return .broaden
        case .emptyCorpus: return .addFiles
        case .modelNotLoaded: return .loadModel
        case .engineUnreachable: return .restartEngine
        }
    }
}

/// Retrievers that can surface below-threshold "nearest" matches for the
/// empty-result path (AT-M12.9).
public protocol NearestProbing: Sendable {
    func nearest(_ q: String, container: String?, limit: Int) async throws -> [Retrieved]
}

public enum QueryEvent: Equatable, Sendable {
    case routed(intent: String, effort: String)   // after routing (M4)
    case understanding(String)  // "Reading across 3 notes…" restatement (expressive #3)
    case sources([SourceCard])
    case token(String)
    case retrying(String)       // self-correction: discard the draft, try again (intelligence #3)
    case citation(sentenceIndex: Int, supported: Bool)   // post-gen verification (M5)
    case suggestions([String])  // expressive follow-up questions (#6)
    case entities([String])     // salient entities to explore (intelligence #8)
    case related([SourceCard])  // see-also documents beyond the cited ones (#8)
    case reasoning([String])    // visible reasoning steps (beats-Siri #1)
    case state(TerminalState)   // non-answer outcome, still a defined output
    case done
}

public protocol QueryServing: Sendable {
    func ask(_ q: String, history: [Turn]) -> AsyncThrowingStream<QueryEvent, Error>
}

public extension QueryServing {
    /// Convenience for a fresh (non-follow-up) question.
    func ask(_ q: String) -> AsyncThrowingStream<QueryEvent, Error> { ask(q, history: []) }
}

/// Retrieval knobs sourced from mnemo.toml — never hardcoded at call sites.
public struct SearchDefaults: Sendable {
    public var searchMode: String
    public var rerank: Bool
    public var threshold: Double
    public var limit: Int
    public var container: String?
    public init(searchMode: String, rerank: Bool, threshold: Double, limit: Int, container: String?) {
        self.searchMode = searchMode
        self.rerank = rerank
        self.threshold = threshold
        self.limit = limit
        self.container = container
    }
}

public struct QueryService: QueryServing {
    // A-261: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-169: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-313: intelligence
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

    // A-105: lifecycle
    // MARK: - Query lifecycle events (M12)
        public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
            switch branch {
            case .routeAmbiguity: return [.reasoning(["Ambiguous route — escalating to structured classification"])]
            case .emptyEvidence: return [.sources([]), .token("I don't have anything in your files about that.")]
            case .retry: return [.retrying("That wasn't grounded — reconsidering using only your files…")]
            }
        }
        public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-209: memory
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

    let retriever: Retrieving
    let generator: Generating
    let spans: SpanResolver
    let defaults: SearchDefaults
    let mountRoot: String    // absolute memory-path; engine filepaths are relative to it
    let ingestIndex: IngestIndex?
    let router: QueryRouter
    let profiles: ProfileFetching?
    let assembler: ContextAssembler
    let effort: EffortPolicy
    let verifier: CitationVerifier?
    let strength: StrengthLedger?
    let emptyFallback: Bool
    let tone: ResponseTone
    let relatedEnabled: Bool
    let cache: AnswerCache?
    let rewriter: QueryRewriting?
    let escalator: RouterEscalating?
    let agentic: AgenticGrep?
    let selfCorrect: Bool
    let documentSearchEnabled: Bool
    let conversationSink: ConversationIngesting?
    let chatRecallEnabled: Bool
    let logSink: QueryLogSink
    let modelId: String?
    let egressCounter: @Sendable () -> Int

    public init(retriever: Retrieving, generator: Generating, spans: SpanResolver,
                defaults: SearchDefaults, mountRoot: String, ingestIndex: IngestIndex? = nil,
                router: QueryRouter = HeuristicRouter(),
                profiles: ProfileFetching? = nil,
                assembler: ContextAssembler = ContextAssembler(tokenBudget: 8000),
                effort: EffortPolicy = EffortPolicy(routing: "low", extraction: "low",
                                                    synthesis: "medium", multihop: "high"),
                verifier: CitationVerifier? = nil,
                strength: StrengthLedger? = nil,
                emptyFallback: Bool = false,
                tone: ResponseTone = .balanced,
                relatedEnabled: Bool = false,
                cache: AnswerCache? = nil,
                rewriter: QueryRewriting? = nil,
                escalator: RouterEscalating? = nil,
                agentic: AgenticGrep? = nil,
                selfCorrect: Bool = false,
                documentSearchEnabled: Bool = false,
                conversationSink: ConversationIngesting? = nil,
                chatRecallEnabled: Bool = false,
                logSink: QueryLogSink = NullQueryLogSink(),
                modelId: String? = nil,
                egressCounter: @escaping @Sendable () -> Int = { 0 }) {
        self.chatRecallEnabled = chatRecallEnabled
        self.emptyFallback = emptyFallback
        self.tone = tone
        self.relatedEnabled = relatedEnabled
        self.cache = cache
        self.rewriter = rewriter
        self.escalator = escalator
        self.agentic = agentic
        self.selfCorrect = selfCorrect
        self.documentSearchEnabled = documentSearchEnabled
        self.conversationSink = conversationSink
        self.retriever = retriever
        self.generator = generator
        self.spans = spans
        self.defaults = defaults
        self.mountRoot = mountRoot
        self.ingestIndex = ingestIndex
        self.router = router
        self.profiles = profiles
        self.assembler = assembler
        self.effort = effort
        self.verifier = verifier
        self.strength = strength
        self.logSink = logSink
        self.modelId = modelId
        self.egressCounter = egressCounter
    }

    private func finishQuery(_ tracker: inout QueryLogTracker,
                             continuation: AsyncThrowingStream<QueryEvent, Error>.Continuation) async {
        await tracker.emit(to: logSink, egressBlockedCount: egressCounter())
        continuation.finish()
    }

    public func ask(_ q0: String, history: [Turn] = []) -> AsyncThrowingStream<QueryEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var tracker = QueryLogTracker(modelId: modelId)
                do {
                    // 1. Route; escalate genuinely ambiguous queries to the model (#4).
                    let routing = router.classify(q0)
                    var intent = routing.intent
                    for event in routing.ambiguityEvents() { continuation.yield(event) }
                    if routing.ambiguous, let escalator { intent = await escalator.classify(q0) }
                    let effortTier = effort.forIntent(intent)
                    tracker.noteRouted(intent: intent.rawValue, effort: effortTier)
                    continuation.yield(.routed(intent: intent.rawValue, effort: effortTier))

                    // Out-of-scope / chit-chat (#9): reply plainly, skip retrieval.
                    if !ScopeClassifier.isCorpusQuestion(q0) {
                        continuation.yield(.token(ScopeClassifier.reply(for: q0)))
                        tracker.noteFirstToken()
                        tracker.noteTerminal("outOfScope")
                        continuation.yield(.done)
                        await finishQuery(&tracker, continuation: continuation)
                        return
                    }

                    // Answer cache (#7): instant repeat, invalidated on corpus change.
                    let corpusVersion = await (ingestIndex?.documentCount ?? 0)
                    if let cache, history.isEmpty,
                       let cached = await cache.lookup(query: q0, container: defaults.container ?? "", corpusVersion: corpusVersion) {
                        continuation.yield(.sources(cached.sources))
                        continuation.yield(.token(cached.answer))
                        tracker.noteFirstToken()
                        tracker.noteTerminal("cached")
                        continuation.yield(.done)
                        await finishQuery(&tracker, continuation: continuation)
                        return
                    }

                    // Query rewriting (#2): skip for short lookup queries (A-047 latency).
                    let q: String
                    if q0.count < 48, intent == .lookup {
                        q = q0
                    } else {
                        q = await rewriter?.rewrite(q0) ?? q0
                    }

                    // Fetch profile concurrently with retrieval (pipelining).
                    async let profileTask: Profile? = {
                        guard let profiles else { return nil }
                        return try? await profiles.profile(q0, container: defaults.container)
                    }()

                    // 2. Gather evidence: decompose (#10) → search → escalate (#1) →
                    //    agentic multi-hop (#1) → time-filter (#5).
                    let gathered = try await gatherEvidence(q, intent: intent)
                    let hits = gathered.hits
                    let broadened = gathered.broadened
                    if hits.isEmpty {
                        // Honesty about readiness (AT-M2.3): if anything is still
                        // being ingested, say "indexing", never a false refusal.
                        if let index = ingestIndex {
                            await index.refresh()
                            if let pending = await index.pendingPaths().first {
                                continuation.yield(.state(.indexing(path: pending)))
                                tracker.noteTerminal("indexing")
                                continuation.yield(.done)
                                await finishQuery(&tracker, continuation: continuation)
                                return
                            }
                            // First-run: no files at all → onboarding, not a refusal.
                            if await index.documentCount == 0 {
                                continuation.yield(.state(.emptyCorpus))
                                tracker.noteTerminal("emptyCorpus")
                                continuation.yield(.done)
                                await finishQuery(&tracker, continuation: continuation)
                                return
                            }
                        }
                        // AT-M12.9: surface nearest below-threshold matches + broaden,
                        // rather than a blank refusal, when we can probe for them.
                        if emptyFallback, let prober = retriever as? NearestProbing,
                           let near = try? await prober.nearest(q0, container: defaults.container, limit: 5),
                           !near.isEmpty {
                            let resolvedNear = await spans.resolve(near)
                            var seenN = Set<String>()
                            let cards = resolvedNear.map {
                                SourceCard(title: $0.source.title, path: absolutePath($0.source.path), docId: $0.source.docId)
                            }.filter { seenN.insert($0.docId).inserted }
                            for event in CorpusSuggester.emptyEvidenceEvents(nearest: cards) { continuation.yield(event) }
                            tracker.noteTerminal("emptyNearest")
                            continuation.yield(.done)
                            await finishQuery(&tracker, continuation: continuation)
                            return
                        }
                        for event in Coverage.emptyEvidenceEvents() { continuation.yield(event) }
                        tracker.noteTerminal("empty")
                        continuation.yield(.done)
                        await finishQuery(&tracker, continuation: continuation)
                        return
                    }
                    // Literal-keyword backstop: if a salient query term never
                    // appears in the evidence (semantic miss on exact tokens
                    // like names/ids), grep the mount and merge the matching
                    // fact lines — and pull the engine's chunk-level document
                    // search too, since chunks often hold the exact token.
                    var gathered2 = hits
                    var backstopSteps = gathered.steps
                    if !mountRoot.isEmpty {
                        let (rescued, note) = KeywordBackstop.rescue(query: q0, evidence: hits, mountRoot: mountRoot)
                        if let note {
                            gathered2 = rescued
                            backstopSteps.append(note)
                            if documentSearchEnabled, let docSearcher = retriever as? DocumentSearching,
                               let chunkHits = try? await docSearcher.searchDocuments(q0, container: defaults.container, limit: 3) {
                                let existing = Set(gathered2.map { $0.memory.prefix(120) })
                                for h in chunkHits where !existing.contains(h.memory.prefix(120)) {
                                    gathered2.append(h)
                                }
                            }
                        }
                    }
                    // Personalized ranking (#7): blend similarity + usage + recency.
                    let resolved0 = await spans.resolve(gathered2)
                    let strengths = await strength?.counts() ?? [:]
                    var resolved = PersonalRanker.rank(resolved0, strength: strengths)
                    // Timeline reconstruction (beats-Siri #3): order chronologically
                    // when the question is about a sequence/history.
                    let shape = AnswerShape.detect(query: q0, intent: intent)
                    if shape == .timeline { resolved = TimelineBuilder.build(from: resolved) }
                    let cards = makeCards(resolved)

                    let phrase = broadened
                        ? "Broadened the search across \(cards.count) notes…"
                        : Understanding.phrase(intent: intent, sourceCount: cards.count)
                    continuation.yield(.understanding(phrase))
                    continuation.yield(.sources(cards))              // sub-second, before tokens

                    // See-also (#8): related documents beyond the cited ones.
                    if relatedEnabled, let prober = retriever as? NearestProbing,
                       let near = try? await prober.nearest(q0, container: defaults.container, limit: 8) {
                        let citedDocs = Set(cards.map(\.docId))
                        let related = makeCards(near.filter { !citedDocs.contains($0.source.docId) })
                        if !related.isEmpty { continuation.yield(.related(Array(related.prefix(3)))) }
                    }

                    // Strengthen retrieved memories (M8): retrieval reinforces.
                    if let strength {
                        for docId in Set(resolved.map { $0.source.docId }) where !docId.isEmpty {
                            await strength.strengthen(docId)
                        }
                    }

                    // Contradiction awareness / reconciliation (beats-Siri #10).
                    let conflicts = ConflictDetector.conflicts(in: resolved)

                    // 3. Assemble context: profile preamble + budget-trimmed evidence,
                    //    shaped to the question and tone; effort adapts to difficulty (#6).
                    let profile = (await profileTask) ?? Profile(statics: [], dynamics: [], memories: [])
                    let assembled = assembler.assemble(intent: intent, question: q0,
                                                        profile: profile, evidence: resolved)
                    let directive = ResponseStyle.directive(shape: shape, tone: tone)
                    let genEffort = AdaptiveEffort.select(effort, intent: intent,
                                                          coverageWeak: broadened, decomposed: gathered.decomposed)
                    let conflictNote = conflicts.isEmpty ? ""
                        : "\n\nNote — conflicting facts found; prefer the most recent and say so:\n"
                            + conflicts.map { "- \($0.note)" }.joined(separator: "\n")
                    // Numeric/duration reasoning (beats-Siri #2): hand the model the
                    // computed figure so it doesn't guess arithmetic. Prior-chat
                    // recall is excluded — only the user's documents count.
                    var numericNote = ""
                    let numericEvidence = resolved.filter { $0.source.title != Self.chatRecallTitle }
                    if NumericReasoner.isNumericQuestion(q0), let n = NumericReasoner.durationNote(in: numericEvidence) {
                        numericNote = "\n\n\(n)"
                    }
                    // Emit the visible reasoning trace (beats-Siri #1).
                    var steps = backstopSteps
                    if !conflicts.isEmpty { steps.append("Reconciled \(conflicts.count) conflicting fact set(s) by recency") }
                    if !numericNote.isEmpty { steps.append("Computed a figure from the dated facts") }
                    steps.append("Answering at \(genEffort) effort")
                    continuation.yield(.reasoning(steps))
                    tracker.noteReasoningStep()
                    tracker.noteContextTokens(assembled.evidence.reduce(0) { $0 + $1.memory.count / 4 })
                    let convo = Prompt.conversation(history)
                    let basePrompt = "\(convo)\(Prompt.context(assembled.evidence))\(conflictNote)\(numericNote)\n\nQuestion: \(q0)"

                    // 4. Generate, with a self-correcting retry (#3) if the first
                    //    answer verifies as ungrounded.
                    func generate(system: String) async throws -> String {
                        var text = ""
                        for try await tok in generator.stream(system: system, prompt: basePrompt) {
                            text += tok
                            tracker.noteFirstToken()
                            continuation.yield(.token(tok))
                        }
                        return text
                    }
                    let system = Prompt.compose(preamble: assembled.preamble, effort: genEffort, style: directive)
                    var answer = try await generate(system: system)
                    var verdicts = await verifier?.verify(answer: answer, evidence: assembled.evidence)

                    if selfCorrect, let v = verdicts, CitationVerifier.allUnsupported(v) {
                        continuation.yield(.retrying("That wasn't grounded — reconsidering using only your files…"))
                        let strict = Prompt.compose(
                            preamble: assembled.preamble, effort: effort.multihop,
                            style: directive + " Answer ONLY from the provided context; if it isn't there, say you don't know.")
                        answer = try await generate(system: strict)
                        verdicts = await verifier?.verify(answer: answer, evidence: assembled.evidence)
                    }

                    // 5. Emit verification flags; wholly-ungrounded → defined state.
                    if let verifier, let v = verdicts {
                        for event in verifier.citationEvents(v) {
                            if case let .citation(_, supported) = event {
                                tracker.noteCitation(supported: supported)
                            }
                            continuation.yield(event)
                        }
                        if CitationVerifier.allUnsupported(v) {
                            continuation.yield(.state(.unsupportedAnswer))
                            tracker.noteTerminal("unsupportedAnswer")
                        } else {
                            tracker.noteTerminal("answered")
                        }
                    } else {
                        tracker.noteTerminal("answered")
                    }

                    // 6. Entities to explore (#8) + follow-up suggestions (expressive #6).
                    let entities = EntityExtractor.entities(in: answer, max: 4)
                    if !entities.isEmpty { continuation.yield(.entities(entities)) }
                    let followUps = FollowUpSuggester.suggest(query: q0, evidence: resolved, max: 3)
                    if !followUps.isEmpty { continuation.yield(.suggestions(followUps)) }

                    // 7. Cache the completed answer for instant identical repeats.
                    if let cache, history.isEmpty {
                        await cache.store(query: q0, container: defaults.container ?? "",
                                          corpusVersion: corpusVersion, answer: answer, sources: cards)
                    }
                    // 8. Write the exchange back to the engine as a conversation (#5),
                    //    in a dedicated "-chat" container so it never pollutes the
                    //    answer corpus but Supermemory still retains the interaction.
                    if let conversationSink, !answer.isEmpty {
                        let chatContainer = defaults.container.map { "\($0)-chat" }
                        try? await conversationSink.ingestConversation(
                            id: Self.conversationId(for: q0),
                            messages: [("user", q0), ("assistant", answer)],
                            container: chatContainer)
                    }
                    continuation.yield(.done)
                    await finishQuery(&tracker, continuation: continuation)
                } catch {
                    for event in Self.lifecycleRetryEvents() { continuation.yield(event) }
                    tracker.noteTerminal("engineUnreachable")
                    continuation.yield(.done)
                    await finishQuery(&tracker, continuation: continuation)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func makeCards(_ hits: [Retrieved]) -> [SourceCard] {
        var seen = Set<String>()
        return hits
            .filter { seen.insert(sourceCardKey($0)).inserted }
            .map { SourceCard(title: $0.source.title, path: absolutePath($0.source.path),
                              docId: $0.source.docId, snippet: $0.context ?? $0.memory,
                              relevance: $0.similarity, updatedAt: $0.source.updatedAt) }
    }

    /// One source chip per document — distinct memories on the same doc collapse for display.
    private func sourceCardKey(_ h: Retrieved) -> String {
        !h.source.docId.isEmpty ? "id:\(h.source.docId)"
            : (!h.source.path.isEmpty ? "path:\(h.source.path)" : "mem:\(h.memory)")
    }

    private func absolutePath(_ enginePath: String) -> String {
        guard !enginePath.isEmpty, !mountRoot.isEmpty, enginePath.hasPrefix("/") else { return enginePath }
        return mountRoot + enginePath
    }

    /// Renderable events when the query path throws instead of finishing silently (A-105).
    /// Overflow-safe conversation id — avoids `abs(Int.min)` trap (A-045).
    static func conversationId(for query: String) -> String {
        "mnemo-\(UInt(bitPattern: query.hashValue))"
    }

    private static func lifecycleRetryEvents() -> [QueryEvent] {
        [.retrying("That didn't work — try asking again."), .state(.engineUnreachable)]
    }
}
