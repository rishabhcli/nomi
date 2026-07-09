import Foundation

/// Human, expressive relative timestamps for when a fact was learned (#5).
public enum RelativeTime {
    private static func parse(_ iso: String) -> Date? {
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: iso) { return d }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: iso)
    }

    public static func format(iso: String?, now: Date = Date()) -> String? {
        guard let iso, let date = parse(iso) else { return nil }
        let s = now.timeIntervalSince(date)
        if s < 0 { return "just now" }
        let minute = 60.0, hour = 3600.0, day = 86400.0, week = 604800.0
        switch s {
        case ..<(minute): return "just now"
        case ..<hour: return "\(Int(s / minute)) min ago"
        case ..<day: return "\(Int(s / hour)) hr ago"
        case ..<week: let d = Int(s / day); return d == 1 ? "yesterday" : "\(d) days ago"
        case ..<(week * 5): return "\(Int(s / week)) wk ago"
        default:
            let df = DateFormatter()
            df.dateFormat = "MMM yyyy"
            return df.string(from: date)
        }
    }
}
