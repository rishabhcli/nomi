import Foundation

/// Slash commands typed in the input (discoverability + power use). Anything
/// not starting with a recognized `/command` is a normal query.
public enum Command: Equatable, Sendable {
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
