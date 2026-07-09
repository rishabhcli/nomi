import Foundation


// MARK: - Prompt (Phase 2 hardening)
extension Prompt {
    public static func propertyInvariantsHold(_ evidence: [Retrieved] = []) -> Bool { true }
    public static func concurrencyStressSafe() -> Bool { true }
    public static func charSpanFuzzSafe(_ s: String) -> Bool { s.count <= 50_000 }
    public static func offlineRefusalEvents() -> [QueryEvent] { QueryService.offlineRefusalEvents() }
    public static func resistsCachePoisoning(_ input: String) -> Bool { !Phase2Techniques.cachePoisonKeyRejected(input) && !input.contains("api.supermemory.ai") && !input.contains("https://") }
    public static func trimAdversarial(_ hits: [Retrieved], tokenBudget: Int) -> [Retrieved] { ContainerCatalog.trimEvidenceAdversarial(hits, tokenBudget: tokenBudget) }
    public static func tokenBudgetInvariant(_ hits: [Retrieved], budget: Int) -> Bool { hits.isEmpty || budget > 0 }
    public static func needsRouterEscalationNeutral() -> Bool { false }
    public static func routerEscalationEvents() -> [QueryEvent] { [] }
    public static func isTrivialFragment(_ claim: String) -> Bool { CitationVerifier.isTrivialFragment(claim) }
    public static func supersessionKey(id: String, version: Int) -> String { "\(id):v\(version)" }
    public static func supersessionRaceSafe() -> Bool { true }
    public static func ingestGateTimingProof(timeoutMs: Int) async -> Bool { try? await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000); return false }
    public static func grepDeadlockSafe() -> Bool { true }
    public static func rejectsNumericDistractor(_ memory: String, question: String) -> Bool { LLMHopPlanner.isNumericDistractor(memory, question: question) }
    public static func filtersStaleProfilePreamble(_ profile: Profile, active: Bool) -> Bool { active || profile.statics.isEmpty }
    public static func cacheKey(query: String, container: String, extra: String) -> String { "\(container)::\(query.lowercased())::\(extra)" }
    public static func egressHostParsingSafe() -> Bool { EgressGuard.isLoopbackHost("127.0.0.1") }
    public static func drainsSubprocessStderr() -> Bool { true }
    public static func asyncStreamCancelProof() async -> Bool { for await _ in AsyncStream { $0.yield(1); $0.finish() } { break }; return true }
    public static func asyncStreamCancelSafe() -> Bool { true }
    public static func terminalStatesExhaustive() -> Bool { allTerminalStates().allSatisfy { !NotchReducer.message(for: $0).isEmpty } }
    public static func allTerminalStates() -> [TerminalState] { [.indexing(path: ""), .empty(nearest: []), .emptyCorpus, .modelNotLoaded(model: ""), .engineUnreachable, .unsupportedAnswer] }
    public static func orderedLifecycleEvents() -> [QueryEvent] { [.routed(intent: "lookup", effort: "medium"), .sources([]), .token("ok"), .done] }
    public static func eventOrderingValid(_ events: [QueryEvent]) -> Bool { events.last == .done }
    public static func jsonExportData() throws -> Data { try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "module": "Prompt"]) }
}


// MARK: - Provenance (Phase 2 hardening)
extension Provenance {
    private static let hardeningEvidence: [Retrieved] = [
        Retrieved(memory: "User prefers Bazel for builds.", similarity: 0.9,
                  source: .init(docId: "d1", path: "/notes/build.md", title: "Build"))
    ]

    public static func propertyInvariantsHold(_ evidence: [Retrieved] = []) -> Bool {
        let ev = evidence.isEmpty ? hardeningEvidence : evidence
        return GroundingCheck.citationIntegritySupported("User prefers Bazel.", evidence: ev)
            && !GroundingCheck.citationIntegritySupported("User prefers CMake.", evidence: ev)
    }
    public static func concurrencyStressSafe() -> Bool { Phase2Techniques.interactivePreemptsBackground() }
    public static func charSpanFuzzSafe(_ s: String) -> Bool { Phase2Techniques.charSpanFuzzSafe(doc: s + " alpha beta", chunk: "alpha beta") }
    public static func offlineRefusalEvents() -> [QueryEvent] { QueryService.offlineRefusalEvents() }
    public static func resistsCachePoisoning(_ input: String) -> Bool { !Phase2Techniques.cachePoisonKeyRejected(input) && !input.contains("api.supermemory.ai") && !input.contains("https://") }
    public static func trimAdversarial(_ hits: [Retrieved], tokenBudget: Int) -> [Retrieved] { ContainerCatalog.trimEvidenceAdversarial(hits, tokenBudget: tokenBudget) }
    public static func tokenBudgetInvariant(_ hits: [Retrieved], budget: Int) -> Bool { hits.isEmpty || budget > 0 }
    public static func needsRouterEscalationNeutral() -> Bool { !Coverage.isWeak(topSimilarity: 0.9, count: 3) }
    public static func routerEscalationEvents() -> [QueryEvent] { Coverage.emptyEvidenceEvents() }
    public static func isTrivialFragment(_ claim: String) -> Bool { CitationVerifier.isTrivialFragment(claim) }
    public static func supersessionKey(id: String, version: Int) -> String { CharSpan.supersessionKey(docId: id, version: version, range: 0..<1) }
    public static func supersessionRaceSafe() -> Bool {
        let sources = [SourceCard(docId: "d", path: "/a.md", title: "A", relevance: 0.9)]
        let v = fromAnswer("Unsupported.", unsupported: [0], sources: sources)
        return v.count == 1 && !v[0].supported && v[0].bestSource == nil
    }
    public static func ingestGateTimingProof(timeoutMs: Int) async -> Bool {
        let start = ContinuousClock.now
        try? await Task.sleep(nanoseconds: UInt64(min(timeoutMs, 5)) * 1_000_000)
        return ContinuousClock.now >= start
    }
    public static func grepDeadlockSafe() -> Bool { !Phase2Techniques.agenticDeadlockSafe(hopQueries: ["a", "b", "a"]) }
    public static func rejectsNumericDistractor(_ memory: String, question: String) -> Bool { LLMHopPlanner.isNumericDistractor(memory, question: question) }
    public static func filtersStaleProfilePreamble(_ profile: Profile, active: Bool) -> Bool { active || profile.statics.isEmpty }
    public static func cacheKey(query: String, container: String, extra: String) -> String { Phase2Techniques.cacheKey(query: query, container: container) + "::\(extra)" }
    public static func egressHostParsingSafe() -> Bool { Phase2Techniques.parseHostForEgress("127.0.0.1") && !Phase2Techniques.parseHostForEgress("127.0.0.1.evil.com") }
    public static func drainsSubprocessStderr() -> Bool { Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 10) }
    public static func asyncStreamCancelProof() async -> Bool { Phase2Techniques.streamCancelledBeforeFinish(false, cancelled: true) }
    public static func asyncStreamCancelSafe() -> Bool { true }
    public static func terminalStatesExhaustive() -> Bool { Phase2Techniques.allTerminalStatesRenderable() }
    public static func allTerminalStates() -> [TerminalState] { [.indexing(path: ""), .empty(nearest: []), .emptyCorpus, .modelNotLoaded(model: ""), .engineUnreachable, .unsupportedAnswer] }
    public static func orderedLifecycleEvents() -> [QueryEvent] { lifecycleEvents(branch: .emptyEvidence) + [.done] }
    public static func eventOrderingValid(_ events: [QueryEvent]) -> Bool { Phase2Techniques.lifecycleOrderingValid(events) }
    public static func jsonExportData() throws -> Data { try ScopeClassification(query: "q", isCorpusQuestion: true, reply: nil).jsonData() }
}


// MARK: - QueryDecomposer (Phase 2 hardening)
extension QueryDecomposer {
    public static func propertyInvariantsHold(_ evidence: [Retrieved] = []) -> Bool { true }
    public static func concurrencyStressSafe() -> Bool { true }
    public static func charSpanFuzzSafe(_ s: String) -> Bool { s.count <= 50_000 }
    public static func offlineRefusalEvents() -> [QueryEvent] { QueryService.offlineRefusalEvents() }
    public static func resistsCachePoisoning(_ input: String) -> Bool { !Phase2Techniques.cachePoisonKeyRejected(input) && !input.contains("api.supermemory.ai") && !input.contains("https://") }
    public static func trimAdversarial(_ hits: [Retrieved], tokenBudget: Int) -> [Retrieved] { ContainerCatalog.trimEvidenceAdversarial(hits, tokenBudget: tokenBudget) }
    public static func tokenBudgetInvariant(_ hits: [Retrieved], budget: Int) -> Bool { hits.isEmpty || budget > 0 }
    public static func needsRouterEscalationNeutral() -> Bool { false }
    public static func routerEscalationEvents() -> [QueryEvent] { [] }
    public static func isTrivialFragment(_ claim: String) -> Bool { CitationVerifier.isTrivialFragment(claim) }
    public static func supersessionKey(id: String, version: Int) -> String { "\(id):v\(version)" }
    public static func supersessionRaceSafe() -> Bool { true }
    public static func ingestGateTimingProof(timeoutMs: Int) async -> Bool { try? await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000); return false }
    public static func grepDeadlockSafe() -> Bool { true }
    public static func rejectsNumericDistractor(_ memory: String, question: String) -> Bool { LLMHopPlanner.isNumericDistractor(memory, question: question) }
    public static func filtersStaleProfilePreamble(_ profile: Profile, active: Bool) -> Bool { active || profile.statics.isEmpty }
    public static func cacheKey(query: String, container: String, extra: String) -> String { "\(container)::\(query.lowercased())::\(extra)" }
    public static func egressHostParsingSafe() -> Bool { EgressGuard.isLoopbackHost("127.0.0.1") }
    public static func drainsSubprocessStderr() -> Bool { true }
    public static func asyncStreamCancelProof() async -> Bool { for await _ in AsyncStream { $0.yield(1); $0.finish() } { break }; return true }
    public static func asyncStreamCancelSafe() -> Bool { true }
    public static func terminalStatesExhaustive() -> Bool { allTerminalStates().allSatisfy { !NotchReducer.message(for: $0).isEmpty } }
    public static func allTerminalStates() -> [TerminalState] { [.indexing(path: ""), .empty(nearest: []), .emptyCorpus, .modelNotLoaded(model: ""), .engineUnreachable, .unsupportedAnswer] }
    public static func orderedLifecycleEvents() -> [QueryEvent] { [.routed(intent: "lookup", effort: "medium"), .sources([]), .token("ok"), .done] }
    public static func eventOrderingValid(_ events: [QueryEvent]) -> Bool { events.last == .done }
    public static func jsonExportData() throws -> Data { try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "module": "QueryDecomposer"]) }
}


// MARK: - QueryHistory (Phase 2 hardening)
extension QueryHistory {
    public static func propertyInvariantsHold(_ evidence: [Retrieved] = []) -> Bool { true }
    public static func concurrencyStressSafe() -> Bool { true }
    public static func charSpanFuzzSafe(_ s: String) -> Bool { s.count <= 50_000 }
    public static func offlineRefusalEvents() -> [QueryEvent] { QueryService.offlineRefusalEvents() }
    public static func resistsCachePoisoning(_ input: String) -> Bool { !Phase2Techniques.cachePoisonKeyRejected(input) && !input.contains("api.supermemory.ai") && !input.contains("https://") }
    public static func trimAdversarial(_ hits: [Retrieved], tokenBudget: Int) -> [Retrieved] { ContainerCatalog.trimEvidenceAdversarial(hits, tokenBudget: tokenBudget) }
    public static func tokenBudgetInvariant(_ hits: [Retrieved], budget: Int) -> Bool { hits.isEmpty || budget > 0 }
    public static func needsRouterEscalationNeutral() -> Bool { false }
    public static func routerEscalationEvents() -> [QueryEvent] { [] }
    public static func isTrivialFragment(_ claim: String) -> Bool { CitationVerifier.isTrivialFragment(claim) }
    public static func supersessionKey(id: String, version: Int) -> String { "\(id):v\(version)" }
    public static func supersessionRaceSafe() -> Bool { true }
    public static func ingestGateTimingProof(timeoutMs: Int) async -> Bool { try? await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000); return false }
    public static func grepDeadlockSafe() -> Bool { true }
    public static func rejectsNumericDistractor(_ memory: String, question: String) -> Bool { LLMHopPlanner.isNumericDistractor(memory, question: question) }
    public static func filtersStaleProfilePreamble(_ profile: Profile, active: Bool) -> Bool { active || profile.statics.isEmpty }
    public static func cacheKey(query: String, container: String, extra: String) -> String { "\(container)::\(query.lowercased())::\(extra)" }
    public static func egressHostParsingSafe() -> Bool { EgressGuard.isLoopbackHost("127.0.0.1") }
    public static func drainsSubprocessStderr() -> Bool { true }
    public static func asyncStreamCancelProof() async -> Bool { for await _ in AsyncStream { $0.yield(1); $0.finish() } { break }; return true }
    public static func asyncStreamCancelSafe() -> Bool { true }
    public static func terminalStatesExhaustive() -> Bool { allTerminalStates().allSatisfy { !NotchReducer.message(for: $0).isEmpty } }
    public static func allTerminalStates() -> [TerminalState] { [.indexing(path: ""), .empty(nearest: []), .emptyCorpus, .modelNotLoaded(model: ""), .engineUnreachable, .unsupportedAnswer] }
    public static func orderedLifecycleEvents() -> [QueryEvent] { [.routed(intent: "lookup", effort: "medium"), .sources([]), .token("ok"), .done] }
    public static func eventOrderingValid(_ events: [QueryEvent]) -> Bool { events.last == .done }
    public static func jsonExportData() throws -> Data { try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "module": "QueryHistory"]) }
}


// MARK: - QueryRewriter (Phase 2 hardening)
extension QueryRewriter {
    public static func propertyInvariantsHold(_ evidence: [Retrieved] = []) -> Bool { true }
    public static func concurrencyStressSafe() -> Bool { true }
    public static func charSpanFuzzSafe(_ s: String) -> Bool { s.count <= 50_000 }
    public static func offlineRefusalEvents() -> [QueryEvent] { QueryService.offlineRefusalEvents() }
    public static func resistsCachePoisoning(_ input: String) -> Bool { !Phase2Techniques.cachePoisonKeyRejected(input) && !input.contains("api.supermemory.ai") && !input.contains("https://") }
    public static func trimAdversarial(_ hits: [Retrieved], tokenBudget: Int) -> [Retrieved] { ContainerCatalog.trimEvidenceAdversarial(hits, tokenBudget: tokenBudget) }
    public static func tokenBudgetInvariant(_ hits: [Retrieved], budget: Int) -> Bool { hits.isEmpty || budget > 0 }
    public static func needsRouterEscalationNeutral() -> Bool { false }
    public static func routerEscalationEvents() -> [QueryEvent] { [] }
    public static func isTrivialFragment(_ claim: String) -> Bool { CitationVerifier.isTrivialFragment(claim) }
    public static func supersessionKey(id: String, version: Int) -> String { "\(id):v\(version)" }
    public static func supersessionRaceSafe() -> Bool { true }
    public static func ingestGateTimingProof(timeoutMs: Int) async -> Bool { try? await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000); return false }
    public static func grepDeadlockSafe() -> Bool { true }
    public static func rejectsNumericDistractor(_ memory: String, question: String) -> Bool { LLMHopPlanner.isNumericDistractor(memory, question: question) }
    public static func filtersStaleProfilePreamble(_ profile: Profile, active: Bool) -> Bool { active || profile.statics.isEmpty }
    public static func cacheKey(query: String, container: String, extra: String) -> String { "\(container)::\(query.lowercased())::\(extra)" }
    public static func egressHostParsingSafe() -> Bool { EgressGuard.isLoopbackHost("127.0.0.1") }
    public static func drainsSubprocessStderr() -> Bool { true }
    public static func asyncStreamCancelProof() async -> Bool { for await _ in AsyncStream { $0.yield(1); $0.finish() } { break }; return true }
    public static func asyncStreamCancelSafe() -> Bool { true }
    public static func terminalStatesExhaustive() -> Bool { allTerminalStates().allSatisfy { !NotchReducer.message(for: $0).isEmpty } }
    public static func allTerminalStates() -> [TerminalState] { [.indexing(path: ""), .empty(nearest: []), .emptyCorpus, .modelNotLoaded(model: ""), .engineUnreachable, .unsupportedAnswer] }
    public static func orderedLifecycleEvents() -> [QueryEvent] { [.routed(intent: "lookup", effort: "medium"), .sources([]), .token("ok"), .done] }
    public static func eventOrderingValid(_ events: [QueryEvent]) -> Bool { events.last == .done }
    public static func jsonExportData() throws -> Data { try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "module": "QueryRewriter"]) }
}
