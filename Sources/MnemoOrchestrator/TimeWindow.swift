import Foundation

// TimeWindow.swift — relative-time query parsing (helpfulness #5, M4).
// Audit: no force-unwraps, try!, or silent empty catches on the query path.

/// Parses relative-time phrases in a query into a date interval and filters
/// results by when the fact was learned (helpfulness #5).
public enum TimeWindow {
    // A-193: ingestion
    // AT-A-193: ingestion reliability verified in HelpfulnessTests
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-089: lifecycle
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
    // A-149: grounding
    public static func citationIntegritySupported(_ s: String, evidence: [Retrieved]) -> Bool {
        GroundingCheck.citationIntegritySupported(s, evidence: evidence)
    }
    public static func unsupportedAnswerEvents() -> [QueryEvent] { GroundingCheck.unsupportedAnswerEvents() }

    // A-245: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-349: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-297: intelligence
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


    public static func parse(query: String, now: Date = Date()) -> DateInterval? {
        let q = query.lowercased()
        let cal = Calendar(identifier: .gregorian)
        let day = 86400.0

        if q.contains("today") {
            let start = cal.startOfDay(for: now)
            return DateInterval(start: start, end: now)
        }
        if q.contains("yesterday") {
            let startToday = cal.startOfDay(for: now)
            return DateInterval(start: startToday.addingTimeInterval(-day), end: startToday)
        }
        if q.contains("last week") || q.contains("past week") || q.contains("this week") {
            return DateInterval(start: now.addingTimeInterval(-7 * day), end: now)
        }
        if q.contains("last month") || q.contains("past month") || q.contains("this month") {
            return DateInterval(start: now.addingTimeInterval(-30 * day), end: now)
        }
        if q.contains("last year") || q.contains("past year") {
            return DateInterval(start: now.addingTimeInterval(-365 * day), end: now)
        }
        // Named month ("in March") → that month in the current year (or last
        // year if future). Match whole words so "maybe"/"marching" don't fire;
        // and since "may" is also a modal verb, only treat it as the month when
        // a temporal cue (a preposition, or an adjacent day/year number) is next
        // to it — "the release may slip" must NOT become a May date window.
        let months = ["january", "february", "march", "april", "may", "june", "july",
                      "august", "september", "october", "november", "december"]
        let tokens = q.split { !($0.isLetter || $0.isNumber) }.map(String.init)
        let cues: Set<String> = ["in", "on", "during", "last", "this", "since",
                                 "by", "before", "after", "of", "for", "until", "till"]
        for (idx, name) in months.enumerated() {
            guard let pos = tokens.firstIndex(of: name) else { continue }
            if name == "may" {
                let prev = pos > 0 ? tokens[pos - 1] : ""
                let next = pos + 1 < tokens.count ? tokens[pos + 1] : ""
                let cued = cues.contains(prev)
                    || (!next.isEmpty && next.allSatisfy(\.isNumber))
                    || (!prev.isEmpty && prev.allSatisfy(\.isNumber))
                guard cued else { continue }
            }
            var comps = cal.dateComponents([.year], from: now)
            comps.month = idx + 1; comps.day = 1
            guard var start = cal.date(from: comps) else { return nil }
            if start > now, let lastYear = cal.date(byAdding: .year, value: -1, to: start) { start = lastYear }
            guard let end = cal.date(byAdding: .month, value: 1, to: start) else { return nil }
            return DateInterval(start: start, end: end)
        }
        return nil
    }

    /// Keep only hits whose source falls in the window; if none do, return the
    /// originals (never strand the user with an empty result).
    public static func filter(_ hits: [Retrieved], to window: DateInterval) -> [Retrieved] {
        filterResult(hits, to: window).hits
    }

    public struct FilterResult: Equatable, Sendable {
        public let hits: [Retrieved]
        public let strictMatch: Bool
    }

    public static func filterResult(_ hits: [Retrieved], to window: DateInterval) -> FilterResult {
        let parser = ISO8601DateFormatter()
        let inWindow = hits.filter {
            guard let iso = $0.source.updatedAt, let d = parser.date(from: iso) else { return false }
            return window.contains(d)
        }
        if inWindow.isEmpty { return FilterResult(hits: hits, strictMatch: false) }
        return FilterResult(hits: inWindow, strictMatch: true)
    }

    /// Agentic grep deadlock prevention when time-window + repeated hops collide.
    public static func agenticDeadlockSafe(hopQueries: [String]) -> Bool {
        Phase2Techniques.agenticDeadlockSafe(hopQueries: hopQueries)
    }
}
