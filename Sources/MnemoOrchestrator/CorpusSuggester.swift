import Foundation

/// Proposes real, askable questions drawn from the user's own documents, so an
/// empty/first-run result is a launchpad rather than a dead end (helpfulness #3).
public enum CorpusSuggester {
    public static func fromCards(_ cards: [SourceCard], max: Int = 3) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        for card in cards {
            let title = card.title.trimmingCharacters(in: .whitespaces)
            guard title.count > 1, title != "Untitled", seen.insert(title.lowercased()).inserted else { continue }
            out.append("What does “\(title)” say?")
            if out.count >= max { break }
        }
        return out
    }

    public static func fromTitles(_ titles: [String], max: Int = 3) -> [String] {
        fromCards(titles.map { SourceCard(title: $0, path: "", docId: $0) }, max: max)
    }
}
