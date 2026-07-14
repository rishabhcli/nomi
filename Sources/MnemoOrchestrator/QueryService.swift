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
    case stage(name: String, elapsedMs: Int)  // a completed pipeline stage + its duration (M1 observability)
    case metrics(QueryMetrics)                 // end-of-query metrics for the trust footer (M1 observability)
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
            return !constituents.isEmpty
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
    let directTraversalPolicy: @Sendable (String) -> Bool
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
    /// Deep-observability bus for the dev dashboard. Nil in normal runs → every
    /// emit is a no-op and no document text leaves the process.
    let trace: DevTrace?

    public init(retriever: Retrieving, generator: Generating, spans: SpanResolver,
                defaults: SearchDefaults, mountRoot: String,
                directTraversalPolicy: @escaping @Sendable (String) -> Bool = { _ in false },
                ingestIndex: IngestIndex? = nil,
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
                egressCounter: @escaping @Sendable () -> Int = { 0 },
                trace: DevTrace? = nil) {
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
        self.directTraversalPolicy = directTraversalPolicy
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
        self.trace = trace
    }

    /// Single finish point for every terminal path: stamp the trust-footer
    /// metrics, emit them just before `.done`, then flush the log line.
    private func finishQuery(_ tracker: inout QueryLogTracker, egressBaseline: Int,
                             continuation: AsyncThrowingStream<QueryEvent, Error>.Continuation) async {
        // Per-query egress delta combines app calls blocked by URLProtocol with
        // non-loopback socket lifetimes observed in the managed process tree.
        // The legacy metrics field is named `egressBlockedCount`, but observed
        // child sockets are violations, not claims about denied syscalls.
        let delta = max(0, egressCounter() - egressBaseline)
        let entry = tracker.finalize(egressBlockedCount: delta)
        continuation.yield(.metrics(QueryMetrics(
            firstTokenMs: entry.firstTokenMs, totalMs: entry.totalMs,
            contextTokens: entry.contextTokenCount,
            verificationPassRate: entry.verificationPassRate,
            egressBlockedCount: delta)))
        continuation.yield(.done)
        if let trace {
            let metrics: JSONValue = .object([
                "firstTokenMs": entry.firstTokenMs.map(JSONValue.int) ?? .null,
                "totalMs": entry.totalMs.map(JSONValue.int) ?? .null,
                "hops": entry.retrievalHopCount.map(JSONValue.int) ?? .null,
                "contextTokens": entry.contextTokenCount.map(JSONValue.int) ?? .null,
                "passRate": entry.verificationPassRate.map(JSONValue.double) ?? .null,
                "egress": .int(delta),
            ])
            await trace.append(queryId: entry.queryId, atMs: entry.totalMs ?? 0, stage: "terminal",
                               phase: "info", durationMs: nil, message: entry.terminalState,
                               data: .object(["state": .string(entry.terminalState ?? "")]))
            await trace.append(queryId: entry.queryId, atMs: entry.totalMs ?? 0, stage: "done",
                               phase: "end", durationMs: entry.totalMs, message: nil,
                               data: .object(["metrics": metrics]))
        }
        await logSink.emit(entry)
        continuation.finish()
    }

    /// Whole milliseconds since `start`, clamped at 0 — for per-stage trace timing.
    private static func elapsedMs(since start: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(start) * 1000))
    }

    public func ask(_ q0: String, history: [Turn] = []) -> AsyncThrowingStream<QueryEvent, Error> {
        AsyncThrowingStream(QueryEvent.self) { continuation in
            let task = Task {
                var tracker = QueryLogTracker(modelId: modelId)
                let egressBaseline = egressCounter()   // per-query egress is the delta from here
                // Deep trace (dev dashboard only) — shares the log's queryId; nil in normal runs.
                let tracer = trace.map { QueryTracer(queryId: tracker.entry.queryId, trace: $0) }
                do {
                    // Out-of-scope / chit-chat (#9) is a synchronous gate. It
                    // must run before routing because ambiguous greetings would
                    // otherwise queue behind the local model just to discover
                    // that no retrieval or generation was needed.
                    if !ScopeClassifier.isCorpusQuestion(q0) {
                        await tracer?.event("scope", "info", message: "out of scope",
                                            data: .object(["corpusQuestion": .bool(false),
                                                           "reply": .string(ScopeClassifier.reply(for: q0))]))
                        tracker.noteRouted(intent: "outOfScope", effort: "none")
                        continuation.yield(.routed(intent: "outOfScope", effort: "none"))
                        continuation.yield(.token(ScopeClassifier.reply(for: q0)))
                        tracker.noteFirstToken()
                        tracker.noteTerminal("outOfScope")
                        await finishQuery(&tracker, egressBaseline: egressBaseline, continuation: continuation)
                        return
                    }
                    await tracer?.event("scope", "info", message: "corpus question",
                                        data: .object(["corpusQuestion": .bool(true)]))

                    // 1. Route; escalate genuinely ambiguous corpus queries to the model (#4).
                    let routing = router.classify(q0)
                    var intent = routing.intent
                    if routing.ambiguous, let escalator {
                        continuation.yield(.reasoning(["Classifying the request locally"]))
                        intent = await escalator.classify(q0)
                    }
                    let effortTier = effort.forIntent(intent)
                    tracker.noteRouted(intent: intent.rawValue, effort: effortTier)
                    continuation.yield(.routed(intent: intent.rawValue, effort: effortTier))
                    for event in routing.ambiguityEvents() { continuation.yield(event) }
                    await tracer?.event("route", "end", message: "\(intent.rawValue) / \(effortTier)",
                                        data: .object(["intent": .string(intent.rawValue),
                                                       "effort": .string(effortTier),
                                                       "ambiguous": .bool(routing.ambiguous)]))

                    // Answer cache (#7): instant repeat, invalidated on corpus change.
                    let corpusRevision = await (ingestIndex?.corpusRevision ?? 0)
                    if let cache, history.isEmpty,
                       let cached = await cache.lookup(query: q0, container: defaults.container ?? "", corpusRevision: corpusRevision) {
                        await tracer?.event("cache", "info", message: "hit", data: .object(["hit": .bool(true)]))
                        continuation.yield(.sources(cached.sources))
                        continuation.yield(.token(cached.answer))
                        tracker.noteFirstToken()
                        tracker.noteTerminal("cached")
                        await finishQuery(&tracker, egressBaseline: egressBaseline, continuation: continuation)
                        return
                    }
                    await tracer?.event("cache", "info", message: "miss", data: .object(["hit": .bool(false)]))

                    // Query rewriting (#2): skip for short lookup queries (A-047 latency).
                    let q: String
                    if q0.count < 48, intent == .lookup {
                        q = q0
                    } else if let rewriter {
                        continuation.yield(.reasoning(["Rewriting the question for local retrieval"]))
                        q = await rewriter.rewrite(q0)
                    } else {
                        q = q0
                    }
                    if q != q0 {
                        await tracer?.event("rewrite", "info", message: "rewritten",
                                            data: .object(["from": .string(q0), "to": .string(q)]))
                    }

                    // Fetch profile concurrently with retrieval (pipelining).
                    async let profileTask: Profile? = {
                        guard let profiles else { return nil }
                        return try? await profiles.profile(q0, container: defaults.container)
                    }()

                    // 2. Gather evidence: decompose (#10) → search → escalate (#1) →
                    //    agentic multi-hop (#1) → time-filter (#5).
                    let tRetrieve = Date()
                    let gathered = try await gatherEvidence(q, intent: intent) { steps in
                        continuation.yield(.reasoning(steps))
                    }
                    continuation.yield(.stage(name: "retrieve", elapsedMs: Self.elapsedMs(since: tRetrieve)))
                    let hits = gathered.hits
                    let broadened = gathered.broadened
                    await tracer?.event("gather.search", "end", message: "\(hits.count) candidates",
                        data: .object(["candidates": .array(hits.prefix(20).map { (h) -> JSONValue in
                            .object(["title": .string(h.source.title), "path": .string(h.source.path),
                                     "score": .double(h.similarity),
                                     "aboveThreshold": .bool(h.similarity >= defaults.threshold),
                                     "snippet": .string(String((h.context ?? h.memory).prefix(200)))])
                        })]))

                    // Literal-keyword rescue must also run when semantic search
                    // returns nothing. Exact filenames, identifiers, and fresh
                    // files can exist locally before their embeddings are ready.
                    var gathered2 = hits
                    var backstopSteps = gathered.steps
                    if !mountRoot.isEmpty, directTraversalPolicy(mountRoot) {
                        let rescueTask = Task.detached(priority: .utility) {
                            try KeywordBackstop.rescueCancellable(
                                query: q0,
                                evidence: hits,
                                mountRoot: mountRoot
                            )
                        }
                        let (rescued, note) = try await withTaskCancellationHandler {
                            try await rescueTask.value
                        } onCancel: {
                            rescueTask.cancel()
                        }
                        try Task.checkCancellation()
                        if let note {
                            gathered2 = rescued
                            backstopSteps.append(note)
                            continuation.yield(.reasoning(backstopSteps))
                            await tracer?.event("backstop", "info", message: note,
                                                data: .object(["triggered": .bool(true),
                                                               "rescued": .int(rescued.count)]))
                        }
                    }

                    if gathered2.isEmpty {
                        // Honesty about readiness (AT-M2.3): if anything is still
                        // being ingested, say "indexing", never a false refusal.
                        if let index = ingestIndex {
                            await index.refresh()
                            if let pending = await index.pendingPaths().first {
                                continuation.yield(.state(.indexing(path: pending)))
                                tracker.noteTerminal("indexing")
                                await finishQuery(&tracker, egressBaseline: egressBaseline, continuation: continuation)
                                return
                            }
                            // First-run: no files at all → onboarding, not a refusal.
                            if await index.documentCount == 0 {
                                continuation.yield(.state(.emptyCorpus))
                                tracker.noteTerminal("emptyCorpus")
                                await finishQuery(&tracker, egressBaseline: egressBaseline, continuation: continuation)
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
                            await finishQuery(&tracker, egressBaseline: egressBaseline, continuation: continuation)
                            return
                        }
                        for event in Coverage.emptyEvidenceEvents() { continuation.yield(event) }
                        tracker.noteTerminal("empty")
                        await finishQuery(&tracker, egressBaseline: egressBaseline, continuation: continuation)
                        return
                    }
                    // Personalized ranking (#7): blend similarity + usage + recency.
                    let resolved0 = await spans.resolve(gathered2)
                    let strengths = await strength?.counts() ?? [:]
                    var resolved = EvidenceSelector.select(
                        PersonalRanker.rank(resolved0, strength: strengths),
                        for: intent
                    )
                    // Timeline reconstruction (beats-Siri #3): order chronologically
                    // when the question is about a sequence/history.
                    let shape = AnswerShape.detect(query: q0, intent: intent)
                    if shape == .timeline { resolved = TimelineBuilder.build(from: resolved) }

                    // 3. Assemble the exact context generation will receive before
                    // emitting source cards. Profile search memories can enter the
                    // evidence pool and the token budget can remove retrieved hits;
                    // the UI must never advertise sources absent from the prompt.
                    let profile = (await profileTask) ?? Profile(statics: [], dynamics: [], memories: [])
                    var assembled = assembler.assemble(intent: intent, question: q0,
                                                       profile: profile, evidence: resolved)
                    if shape == .timeline {
                        assembled = AssembledContext(
                            preamble: assembled.preamble,
                            evidence: TimelineBuilder.build(from: assembled.evidence),
                            tokenBudget: assembled.tokenBudget
                        )
                    }
                    let generationEvidence = assembled.evidence
                    let cards = makeCards(generationEvidence)

                    let phrase = broadened
                        ? "Broadened the search across \(cards.count) notes…"
                        : Understanding.phrase(intent: intent, sourceCount: cards.count)
                    continuation.yield(.understanding(phrase))
                    backstopSteps.append(
                        "Reading \(cards.count) source\(cards.count == 1 ? "" : "s") for the answer"
                    )
                    continuation.yield(.reasoning(backstopSteps))
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
                        for docId in Set(generationEvidence.map { $0.source.docId }) where !docId.isEmpty {
                            await strength.strengthen(docId)
                        }
                    }

                    // Contradiction awareness / reconciliation (beats-Siri #10).
                    let conflicts = ConflictDetector.conflicts(in: generationEvidence)

                    // Shape the prompt and adapt effort to difficulty (#6).
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
                    let numericEvidence = generationEvidence.filter { $0.source.title != Self.chatRecallTitle }
                    if NumericReasoner.isNumericQuestion(q0), let n = NumericReasoner.durationNote(in: numericEvidence) {
                        numericNote = "\n\n\(n)"
                    }
                    // Emit the visible reasoning trace (beats-Siri #1).
                    var steps = backstopSteps
                    if !conflicts.isEmpty { steps.append("Reconciled \(conflicts.count) conflicting fact set(s) by recency") }
                    if !numericNote.isEmpty { steps.append("Computed a figure from the dated facts") }
                    steps.append("Synthesizing a grounded answer at \(genEffort) effort")
                    continuation.yield(.reasoning(steps))
                    tracker.noteReasoningStep()
                    tracker.noteContextTokens(assembled.evidence.reduce(0) { $0 + $1.memory.count / 4 })
                    let convo = Prompt.conversation(history)
                    let basePrompt = "\(convo)\(Prompt.context(assembled.evidence))\(conflictNote)\(numericNote)\n\nQuestion: \(q0)"

                    // 4. Generate, with a self-correcting retry (#3) if the first
                    //    answer verifies as ungrounded.
                    func generate(system: String, generationEffort: String) async throws -> String {
                        var text = ""
                        for try await tok in generator.stream(
                            system: system,
                            prompt: basePrompt,
                            effort: generationEffort
                        ) {
                            text += tok
                            tracker.noteFirstToken()
                            await tracer?.event("generate", "token", data: .object(["tokenText": .string(tok)]))
                            continuation.yield(.token(tok))
                        }
                        return text
                    }
                    let system = Prompt.compose(preamble: assembled.preamble, effort: genEffort, style: directive)
                    await tracer?.event("assemble", "end", message: "\(assembled.evidence.count) chunks",
                        data: .object(["system": .string(system),
                                       "context": .string(Prompt.context(assembled.evidence)),
                                       "question": .string(q0),
                                       "contextTokens": .int(assembled.evidence.reduce(0) { $0 + $1.memory.count / 4 })]))
                    let tGenerate = Date()
                    var answer = try await generate(system: system, generationEffort: genEffort)
                    continuation.yield(.stage(name: "generate", elapsedMs: Self.elapsedMs(since: tGenerate)))
                    if verifier != nil {
                        steps.append("Checking every claim against your files")
                        continuation.yield(.reasoning(steps))
                    }
                    let tVerify = Date()
                    var verdicts = await verifier?.verify(answer: answer, evidence: assembled.evidence)
                    if verifier != nil {
                        continuation.yield(.stage(name: "verify", elapsedMs: Self.elapsedMs(since: tVerify)))
                    }

                    if selfCorrect, let v = verdicts, CitationVerifier.allUnsupported(v) {
                        continuation.yield(.retrying("That wasn't grounded — reconsidering using only your files…"))
                        let strict = Prompt.compose(
                            preamble: assembled.preamble, effort: effort.multihop,
                            style: directive + " Answer ONLY from the provided context; if it isn't there, say you don't know.")
                        answer = try await generate(system: strict, generationEffort: effort.multihop)
                        verdicts = await verifier?.verify(answer: answer, evidence: assembled.evidence)
                    }
                    await tracer?.event("generate", "end", message: "\(answer.count) chars",
                                        data: .object(["answer": .string(answer)]))

                    // 5. Emit verification flags; wholly-ungrounded → defined state.
                    var answerIsGrounded = true
                    if let verifier, let v = verdicts {
                        var verdictArr: [JSONValue] = []
                        var supportedCount = 0
                        for event in verifier.citationEvents(v) {
                            if case let .citation(idx, supported) = event {
                                tracker.noteCitation(supported: supported)
                                if supported { supportedCount += 1 }
                                verdictArr.append(.object(["sentence": .int(idx), "supported": .bool(supported)]))
                            }
                            continuation.yield(event)
                        }
                        if !verdictArr.isEmpty {
                            await tracer?.event("verify", "end",
                                data: .object(["verdicts": .array(verdictArr),
                                               "passRate": .double(Double(supportedCount) / Double(verdictArr.count))]))
                        }
                        if CitationVerifier.allUnsupported(v) {
                            answerIsGrounded = false
                            continuation.yield(.state(.unsupportedAnswer))
                            tracker.noteTerminal("unsupportedAnswer")
                        } else {
                            tracker.noteTerminal("answered")
                        }
                    } else {
                        tracker.noteTerminal("answered")
                    }

                    // Rejected drafts are terminal UI values, never knowledge.
                    // Do not derive suggestions from, cache, or write an answer
                    // that the verifier could not ground after correction.
                    if answerIsGrounded {
                        // 6. Entities to explore (#8) + follow-up suggestions (expressive #6).
                        let entities = EntityExtractor.entities(in: answer, max: 4)
                        if !entities.isEmpty { continuation.yield(.entities(entities)) }
                        let followUps = FollowUpSuggester.suggest(
                            query: q0,
                            evidence: generationEvidence,
                            max: 3
                        )
                        if !followUps.isEmpty { continuation.yield(.suggestions(followUps)) }

                        // 7. Cache the completed answer for instant identical repeats.
                        if let cache, history.isEmpty {
                            await cache.store(query: q0, container: defaults.container ?? "",
                                              corpusRevision: corpusRevision, answer: answer, sources: cards)
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
                    }
                    await finishQuery(&tracker, egressBaseline: egressBaseline, continuation: continuation)
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    for event in Self.lifecycleRetryEvents() { continuation.yield(event) }
                    tracker.noteTerminal("engineUnreachable")
                    await finishQuery(&tracker, egressBaseline: egressBaseline, continuation: continuation)
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
        if enginePath == mountRoot || enginePath.hasPrefix(mountRoot + "/") {
            return enginePath
        }
        if enginePath.hasPrefix("/Volumes/")
            || FileManager.default.fileExists(atPath: enginePath) {
            return enginePath
        }
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
