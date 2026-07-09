import Foundation

/// Detects actionable items in an answer (helpfulness #10): links, emails,
/// phone numbers, and dates the user might want to copy or open.
public struct DetectedAction: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case url, email, phone, date }
    public let kind: Kind
    public let value: String
}

public enum ActionExtractor {
    public static func extract(_ text: String) -> [DetectedAction] {
        var out: [DetectedAction] = []
        var seen = Set<String>()
        func add(_ kind: DetectedAction.Kind, _ value: String) {
            let v = value.trimmingCharacters(in: .whitespaces)
            guard !v.isEmpty, seen.insert("\(kind)|\(v.lowercased())").inserted else { return }
            out.append(DetectedAction(kind: kind, value: v))
        }

        // Emails first (so their host isn't also grabbed as a URL).
        let emailRE = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
        let emails = matches(emailRE, in: text)
        emails.forEach { add(.email, $0) }
        let emailSet = Set(emails)

        for url in matches(#"https?://[^\s)\]]+"#, in: text) { add(.url, url) }

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue | NSTextCheckingResult.CheckingType.date.rawValue) {
            let ns = text as NSString
            detector.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
                guard let m else { return }
                if m.resultType == .phoneNumber, let p = m.phoneNumber { add(.phone, p) }
                if m.resultType == .date {
                    let s = ns.substring(with: m.range)
                    if !emailSet.contains(where: { $0.contains(s) }) { add(.date, s) }
                }
            }
        }
        return out
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }
}
