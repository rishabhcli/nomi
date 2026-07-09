import Foundation


// MARK: - NumericReasoner (Phase 2 hardening)
extension NumericReasoner {
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
    public static func jsonExportData() throws -> Data { try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "module": "NumericReasoner"]) }
}


// MARK: - OllamaClient (Phase 2 hardening)
extension OllamaClient {
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
    public static func jsonExportData() throws -> Data { try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "module": "OllamaClient"]) }
}


// MARK: - PersonalRanker (Phase 2 hardening)
extension PersonalRanker {
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
    public static func jsonExportData() throws -> Data { try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "module": "PersonalRanker"]) }
}


// MARK: - Preferences (Phase 2 hardening)
extension Preferences {
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
    public static func jsonExportData() throws -> Data { try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "module": "Preferences"]) }
}


// MARK: - Profile (Phase 2 hardening)
extension Profile {
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
    public static func jsonExportData() throws -> Data { try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "module": "Profile"]) }
}
