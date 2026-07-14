import Foundation

/// Searches several source containers at once and merges the results, so one query
/// can draw on files + messages + mail + … in a single pass. Fans the query out
/// concurrently (one search per enabled container), dedups by document keeping the
/// strongest hit, and returns the top matches by similarity.
///
/// Additive by design: with an empty container set it is a straight passthrough to
/// the base retriever, so existing single-container behavior is unchanged. (M13)
public struct MultiContainerRetriever: Retrieving {
    public let base: Retrieving
    public let containers: [String]

    public init(base: Retrieving, containers: [String]) {
        self.base = base
        self.containers = containers
    }

    public func search(_ req: SearchRequest) async throws -> [Retrieved] {
        guard !containers.isEmpty else { return try await base.search(req) }

        var perContainer: [[Retrieved]] = []
        try await withThrowingTaskGroup(of: [Retrieved].self) { group in
            for container in containers {
                var scoped = req
                scoped.container = container
                group.addTask { [base] in try await base.search(scoped) }
            }
            for try await hits in group { perContainer.append(hits) }
        }

        // Dedup by document id (fall back to the memory text when the engine gave
        // no doc id), keeping the highest-similarity hit for each document.
        var best: [String: Retrieved] = [:]
        var order: [String] = []
        for hits in perContainer {
            for hit in hits {
                let key = hit.source.docId.isEmpty ? hit.memory : hit.source.docId
                if let existing = best[key] {
                    if hit.similarity > existing.similarity { best[key] = hit }
                } else {
                    best[key] = hit
                    order.append(key)
                }
            }
        }
        let merged = order.compactMap { best[$0] }.sorted { $0.similarity > $1.similarity }
        return Array(merged.prefix(req.limit))
    }
}
