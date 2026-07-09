import Foundation

/// Distinguishes real corpus questions from greetings / meta chit-chat, so the
/// assistant doesn't force a citation-hunting answer onto "hi" (intelligence #9).
public enum ScopeClassifier {
    private static let chitChat: Set<String> = [
        "hi", "hey", "hello", "yo", "sup", "thanks", "thank you", "thx", "ok", "okay",
        "cool", "nice", "great", "bye", "goodbye", "good morning", "good night",
        "who are you", "what are you", "what can you do", "help me", "what is this",
    ]

    public static func isCorpusQuestion(_ query: String) -> Bool {
        let q = query.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " ?!.,"))
        if q.isEmpty { return false }
        if chitChat.contains(q) { return false }
        // Very short non-question fragments that are pure greetings.
        if q.split(separator: " ").count <= 2 && chitChat.contains(where: { q.hasPrefix($0) }) { return false }
        return true
    }

    /// A friendly, honest reply for non-corpus input.
    public static func reply(for query: String) -> String {
        let q = query.lowercased()
        if q.contains("who are you") || q.contains("what are you") {
            return "I'm Mnemo — an on-device assistant that answers from your own files, fully offline."
        }
        if q.contains("what can you do") || q.contains("help") {
            return "Ask me anything about your files and I'll answer with citations. Type /help for commands."
        }
        if q.contains("thank") { return "Anytime." }
        return "Hi. Ask me something about your files and I'll dig in — or type /help."
    }
}
