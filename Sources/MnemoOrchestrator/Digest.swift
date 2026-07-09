import Foundation

/// A proactive "since last time" summary shown on summon (beats-Siri #5 —
/// initiative). Empty when there's nothing worth interrupting the user for.
public enum Digest {
    public static func build(readyCount: Int, processingCount: Int, failedCount: Int,
                             newSinceLast: Int, conflictsResolved: Int) -> String {
        var parts: [String] = []
        if newSinceLast > 0 { parts.append("\(newSinceLast) new fact\(newSinceLast == 1 ? "" : "s") learned") }
        if conflictsResolved > 0 { parts.append("\(conflictsResolved) contradiction\(conflictsResolved == 1 ? "" : "s") resolved") }
        if processingCount > 0 { parts.append("\(processingCount) file\(processingCount == 1 ? "" : "s") indexing") }
        if failedCount > 0 { parts.append("\(failedCount) need attention") }
        guard !parts.isEmpty else { return "" }
        return "Since last time: " + parts.joined(separator: ", ") + "."
    }
}
