import Foundation

/// Slash commands typed in the input (discoverability + power use). Anything
/// not starting with a recognized `/command` is a normal query.
public enum Command: Equatable, Sendable {
    // A-095: lifecycle
    // MARK: - Query lifecycle events (M12)
        public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
            switch branch {
            case .routeAmbiguity:
                return [.reasoning(["Ambiguous route — escalating to structured classification"])]
            case .emptyEvidence:
                return [.sources([]), .token("I don't have anything in your files about that.")]
            case .retry:
                return [.retrying("That wasn't grounded — reconsidering using only your files…")]
            }
        }
        public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }
    case help
    case clear          // start a fresh conversation
    case inspect        // open the memory inspector
    case profile        // show what Mnemo knows about you
    case forget(String) // retract a fact by its text
    case scope(String)  // scope subsequent queries to a container
    case tone(String)   // set response tone (brief|balanced|detailed)
    case more           // re-ask the last question, deeper/broadened
    case why            // provenance chain for the last answer (beats-Siri #7)
    case entity(String) // knowledge panel for an entity (beats-Siri #4)
    case preferences    // the learned model of you, made explicit (beats-Siri #9)
}

public enum ParsedInput: Equatable, Sendable {
    case query(String)
    case command(Command)
}

public enum CommandParser {
    // A-199: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-303: intelligence
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

    // A-155: grounding
    public static func citationIntegritySupported(_ s: String, evidence: [Retrieved]) -> Bool {
        GroundingCheck.citationIntegritySupported(s, evidence: evidence)
    }
    public static func unsupportedAnswerEvents() -> [QueryEvent] { GroundingCheck.unsupportedAnswerEvents() }

    // A-251: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    public static func parse(_ raw: String) -> ParsedInput {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return .query(raw) }

        let body = String(trimmed.dropFirst())
        let parts = body.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let verb = parts.first?.lowercased() else { return .command(.help) }
        let arg = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""

        switch verb {
        case "help", "?": return .command(.help)
        case "clear", "new": return .command(.clear)
        case "inspect", "memories": return .command(.inspect)
        case "profile", "me": return .command(.profile)
        case "forget": return arg.isEmpty ? .command(.help) : .command(.forget(arg))
        case "scope": return arg.isEmpty ? .command(.help) : .command(.scope(arg))
        case "tone": return arg.isEmpty ? .command(.help) : .command(.tone(arg.lowercased()))
        case "more", "deeper": return .command(.more)
        case "why", "sources": return .command(.why)
        case "entity", "about": return arg.isEmpty ? .command(.help) : .command(.entity(arg))
        case "preferences", "prefs": return .command(.preferences)
        default: return .command(.help)
        }
    }

    public static let helpText = """
    Commands you can type:
    /help — show this list
    /forget <fact> — retract a memory (survives re-ingest)
    /scope <container> — limit answers to a folder scope (e.g. work)
    /tone brief|balanced|detailed — how expansive answers are
    /more — re-ask the last question in more depth
    /why — show why I said that (claim → source)
    /entity <name> — everything I know about an entity
    /preferences — the model of you I've learned (inspectable)
    /inspect — open the memory inspector
    /profile — show what Mnemo knows about you
    /clear — start a fresh conversation
    Anything else is answered from your files.
    """
}

// M11 scheduling budget (A-355)
extension CommandParser {
    public enum Scheduling {
        public static let budgetUs: UInt64 = 40
        public static func registerBudget() { SchedulingBudget.register("CommandParser", budgetUs: budgetUs) }
        /// Cooperative yield hook for background callers on the interactive path.
        public static func yieldIfInteractiveWaiting(_ scheduler: WorkScheduler?) async {
            guard let scheduler, await scheduler.shouldBackgroundYield else { return }
        }
    }
}
