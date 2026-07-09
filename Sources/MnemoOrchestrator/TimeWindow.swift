import Foundation

/// Parses relative-time phrases in a query into a date interval and filters
/// results by when the fact was learned (helpfulness #5).
public enum TimeWindow {
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
        let parser = ISO8601DateFormatter()
        let inWindow = hits.filter {
            guard let iso = $0.source.updatedAt, let d = parser.date(from: iso) else { return false }
            return window.contains(d)
        }
        return inWindow.isEmpty ? hits : inWindow
    }
}
