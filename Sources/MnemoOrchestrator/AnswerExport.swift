import Foundation

/// Renders an answer + its citations as portable Markdown (helpfulness #6).
public enum AnswerExport {
    public static func markdown(question: String, answer: String, sources: [SourceCard]) -> String {
        var out = "> Answered by Mnemo (on-device)\n\n"
        out += "**Q: \(question)**\n\n"
        out += answer.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        if !sources.isEmpty {
            out += "\n**Sources**\n"
            for s in sources {
                var line = "- \(s.title) — `\(s.path)`"
                if let snippet = s.snippet, !snippet.isEmpty { line += "\n  > \(snippet)" }
                out += line + "\n"
            }
        }
        return out
    }
}
