import Foundation

/// A knowledge card aggregating everything the corpus says about one entity
/// (beats-Siri #4 — an entity panel over YOUR data, not a generic web card).
public struct EntityPanel: Equatable, Sendable {
    public let entity: String
    public let facts: [String]
    public let sources: [SourceCard]
}

public extension EntityPanel {
    static func build(entity: String, from evidence: [Retrieved]) -> EntityPanel {
        let needle = entity.lowercased()
        let matching = evidence.filter { $0.memory.lowercased().contains(needle) }
        var seenFacts = Set<String>()
        let facts = matching.map(\.memory).filter { seenFacts.insert($0).inserted }
        var seenDocs = Set<String>()
        let sources = matching.compactMap { hit -> SourceCard? in
            let key = hit.source.docId.isEmpty ? hit.source.path : hit.source.docId
            guard seenDocs.insert(key).inserted else { return nil }
            return SourceCard(title: hit.source.title, path: hit.source.path, docId: hit.source.docId,
                              snippet: hit.memory, relevance: hit.similarity, updatedAt: hit.source.updatedAt)
        }
        return EntityPanel(entity: entity, facts: facts, sources: sources)
    }
}
