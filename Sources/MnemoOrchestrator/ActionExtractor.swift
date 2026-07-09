import Foundation

/// Detects actionable items in an answer (helpfulness #10): links, emails,
/// phone numbers, and dates the user might want to copy or open.
public struct DetectedAction: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case url, email, phone, date }
    public let kind: Kind
    public let value: String
}

public enum ActionExtractor {
    // A-103: lifecycle
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] { switch branch { case .routeAmbiguity: return [.reasoning(["Ambiguous route"])]; case .emptyEvidence: return [.sources([]), .token("No match.")]; case .retry: return [.retrying("Retrying…")] } }
    public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-259: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-311: intelligence
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

    // A-207: memory
    // MARK: - Memory dynamics (M6)
        /// Active memories only — forgotten and TTL-expired facts are excluded.
        public static func memoryDynamicsActive(_ entry: MemoryEntry, now: Date = Date()) -> Bool {
            guard entry.isLatest && !entry.isForgotten else { return false }
            guard let forgetAfter = entry.forgetAfter,
                  let expiry = ISO8601DateFormatter().date(from: forgetAfter) else { return true }
            return now < expiry
        }

        public static func memoryDynamicsFilter(_ entries: [MemoryEntry], now: Date = Date()) -> [MemoryEntry] {
            entries.filter { memoryDynamicsActive($0, now: now) }
        }

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

        for url in matches(#"https?://[^\s)\]]+"#, in: text) {
            if actionHostIsLoopback(url) { add(.url, url) }
        }

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

    /// Only surface loopback URLs — external links are not actionable offline.
    public static func actionHostIsLoopback(_ urlString: String) -> Bool {
        guard let host = URL(string: urlString)?.host else { return false }
        return EgressGuard.isLoopbackHost(host)
    }
}
