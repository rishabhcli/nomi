import Foundation

/// Intent-aware final evidence budget. Retrieval can stay broad, while the
/// local model receives a compact, source-diverse context instead of paying to
/// reread every near-duplicate chunk for a simple lookup.
public enum EvidenceSelector {
    public static func limit(for intent: Intent) -> Int {
        switch intent {
        case .lookup: return 6
        case .profile: return 8
        case .synthesis: return 12
        case .multihop: return 16
        }
    }

    public static func select(_ ranked: [Retrieved], for intent: Intent) -> [Retrieved] {
        let cap = limit(for: intent)
        guard ranked.count > cap else { return ranked }

        var selected: [Retrieved] = []
        var selectedIndexes = Set<Int>()
        var sources = Set<String>()

        // First pass: preserve the ranker's order while spreading evidence
        // across documents. This keeps one verbose file from crowding out the
        // cross-document facts that make Mnemo useful.
        for (index, hit) in ranked.enumerated() {
            let key = sourceKey(hit)
            guard sources.insert(key).inserted else { continue }
            selected.append(hit)
            selectedIndexes.insert(index)
            if selected.count == cap { return selected }
        }

        // If there are fewer distinct documents than the budget, fill the
        // remainder with the highest-ranked extra passages.
        for (index, hit) in ranked.enumerated() where !selectedIndexes.contains(index) {
            selected.append(hit)
            if selected.count == cap { break }
        }
        return selected
    }

    private static func sourceKey(_ hit: Retrieved) -> String {
        if !hit.source.docId.isEmpty { return "id:\(hit.source.docId)" }
        if !hit.source.path.isEmpty { return "path:\(hit.source.path)" }
        return "memory:\(hit.memory.prefix(120))"
    }
}
