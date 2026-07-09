import Foundation

/// Recent-query ring with Up/Down recall (#10). A cursor walks backwards
/// through history on `previous()` and forwards (to an empty fresh input) on
/// `next()`. Consecutive duplicates are collapsed.
public struct QueryHistory: Equatable, Sendable {
    public private(set) var entries: [String] = []
    private var cursor = 0
    private let cap: Int

    public init(cap: Int = 50) { self.cap = cap }

    public mutating func remember(_ q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if entries.last != trimmed { entries.append(trimmed) }
        if entries.count > cap { entries.removeFirst(entries.count - cap) }
        cursor = entries.count
    }

    /// Older query, or nil when there's no history at all.
    public mutating func previous() -> String? {
        guard !entries.isEmpty else { return nil }
        cursor = max(0, cursor - 1)
        return entries[cursor]
    }

    /// Newer query; "" past the newest (fresh input); nil when no history.
    public mutating func next() -> String? {
        guard !entries.isEmpty else { return nil }
        cursor = min(entries.count, cursor + 1)
        return cursor < entries.count ? entries[cursor] : ""
    }
}
