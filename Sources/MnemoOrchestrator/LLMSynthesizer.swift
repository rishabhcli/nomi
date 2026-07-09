import Foundation

/// Synthesizes a higher-level memory from a cluster with the local model.
/// The synthesized fact must stay grounded in its constituents (M5 still
/// applies when it's later used in an answer).
public struct LLMSynthesizer: PatternSynthesizing {
    let generator: Generating

    public init(generator: Generating) { self.generator = generator }

    static let system = """
    You consolidate several related personal facts into ONE higher-level fact. \
    Output a single first-person or third-person statement that captures the \
    shared pattern, faithful to the inputs — invent nothing. No preamble, one sentence.
    """

    public func synthesize(_ cluster: [MemoryEntry]) async -> String? {
        guard cluster.count >= 2 else { return nil }
        let block = cluster.map { "- \($0.memory)" }.joined(separator: "\n")
        let prompt = "FACTS:\n\(block)\n\nOne consolidated fact:"
        var raw = ""
        do {
            for try await tok in generator.stream(system: Self.system, prompt: prompt) { raw += tok }
        } catch { return nil }
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first ?? raw
        let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}
