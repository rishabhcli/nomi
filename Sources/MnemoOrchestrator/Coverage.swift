import Foundation

/// Decides when a search result is too thin to answer well, and how to broaden
/// it (helpfulness #1 — the PLAN.md M4 "auto-escalate on weak coverage" gate).
public enum Coverage {
    /// Weak = nothing found, or the best match is only loosely relevant.
    public static func isWeak(topSimilarity: Double, count: Int) -> Bool {
        count == 0 || topSimilarity < 0.5
    }

    /// A broadened request: hybrid chunks, a relaxed threshold, and more results.
    public static func escalate(_ base: SearchRequest) -> SearchRequest {
        SearchRequest(q: base.q,
                      searchMode: "hybrid",
                      rerank: base.rerank,
                      threshold: max(0.1, base.threshold * 0.5),
                      limit: base.limit * 2,
                      container: base.container)
    }
}
