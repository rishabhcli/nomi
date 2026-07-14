// KeywordBackstop.swift — literal grep rescue for semantic misses (M3, M4).
// Public entry points:
//   KeywordBackstop.salientTerms — content-bearing query terms (≥3 chars)
//   KeywordBackstop.uncovered — terms absent from evidence corpus
//   KeywordBackstop.grep — literal mount grep for one term
//   KeywordBackstop.rescue — full backstop: find gaps, grep, merge hits
//   KeywordBackstop.LifecycleBranch — query lifecycle event branches (M12)

import Foundation

/// Literal-keyword rescue for semantic retrieval misses.
///
/// Semantic search can whiff on exact tokens ("Chrome", "Bansal", "421") when
/// a document's embedding centers elsewhere — the engine's memories then never
/// mention the term and the model truthfully answers "not in the documents".
/// Before generation, this backstop greps the mount for salient query terms
/// that no evidence covers and merges the matching paragraphs as evidence.
/// Purely local file IO; no model, no network.
public enum KeywordBackstop {
    public static let maximumScannedFiles = 10_000

    /// Query-time recursive traversal is only appropriate for predictable local
    /// filesystems. The production SMFS surface is loopback NFS and must stay on
    /// its indexed search path; a blocking mount syscall cannot be bounded by a
    /// cooperative Swift task timeout.
    public static func supportsDirectTraversal(fileSystemType rawValue: String?) -> Bool {
        guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        else { return false }
        return value == "apfs" || value == "hfs"
    }

    /// Hard limits for the synchronous filesystem fallback. The semantic path
    /// remains primary; literal rescue may inspect only a small, predictable
    /// slice of the mount before returning control to the interactive query.
    public struct IOLimits: Equatable, Sendable {
        public var maximumFiles: Int
        public var maximumBytes: Int
        public var maximumBytesPerFile: Int
        public var maximumDurationSeconds: Double

        public init(
            maximumFiles: Int = KeywordBackstop.maximumScannedFiles,
            maximumBytes: Int = 16 * 1_024 * 1_024,
            maximumBytesPerFile: Int = 2 * 1_024 * 1_024,
            maximumDurationSeconds: Double = 0.75
        ) {
            self.maximumFiles = max(0, maximumFiles)
            self.maximumBytes = max(0, maximumBytes)
            self.maximumBytesPerFile = max(0, maximumBytesPerFile)
            self.maximumDurationSeconds = max(0, maximumDurationSeconds)
        }
    }

    private struct ScanBudget {
        let limits: IOLimits
        let startedAt = ProcessInfo.processInfo.systemUptime
        var visitedFiles = 0
        var readBytes = 0

        var expired: Bool {
            limits.maximumDurationSeconds == 0
                || ProcessInfo.processInfo.systemUptime - startedAt >= limits.maximumDurationSeconds
        }

        mutating func admitFile() -> Bool {
            guard !expired, visitedFiles < limits.maximumFiles else { return false }
            visitedFiles += 1
            return true
        }

        var remainingBytes: Int { max(0, limits.maximumBytes - readBytes) }

        mutating func consume(_ count: Int) {
            readBytes = min(limits.maximumBytes, readBytes + max(0, count))
        }
    }
    // A-179: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-123: grounding
    public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    // A-323: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-167: ingestion
    // MARK: - Ingestion reliability (M2)

    // A-271: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return !constituents.isEmpty
        }

    // A-115: lifecycle
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

    // A-219: memory
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

    static let stopwords: Set<String> = [
        "what", "when", "where", "which", "whose", "who", "whom", "why", "how",
        "is", "are", "was", "were", "am", "be", "been", "being", "do", "does",
        "did", "have", "has", "had", "the", "a", "an", "my", "your", "our",
        "their", "his", "her", "its", "of", "in", "on", "at", "to", "for",
        "from", "with", "about", "according", "and", "or", "but", "not", "no",
        "many", "much", "there", "that", "this", "these", "those", "it", "me",
        "i", "you", "we", "they", "status", "state", "current", "currently",
        "notes", "note", "files", "file", "documents", "document", "say",
        "says", "said", "tell", "show", "list", "give", "get", "any", "some",
    ]

    /// Content-bearing query terms worth a literal search (≥3 chars, not a
    /// stopword). Lowercased.
    public static func salientTerms(_ query: String) -> [String] {
        query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stopwords.contains($0) && Int($0) == nil }
    }

    /// Terms whose stem appears in no evidence text — retrieval never
    /// surfaced them, even as an inflection. Prior-conversation recall is
    /// ignored: an old *answer* mentioning a term is not document coverage.
    public static func uncovered(terms: [String], in evidence: [Retrieved]) -> [String] {
        let corpus = evidence
            .filter { $0.source.title != QueryService.chatRecallTitle }
            .map { ($0.memory + " " + ($0.context ?? "") + " " + $0.source.title).lowercased() }
            .joined(separator: "\n")
        return terms.filter { !corpus.contains(stem($0)) }
    }

    /// Case-insensitive literal grep over the mount's text files, returning
    /// the containing paragraph(s) as synthetic evidence.
    public static func grep(term: String, root: String, maxMatches: Int) -> [Retrieved] {
        best(terms: [term], root: root, wantDigits: false, maxMatches: maxMatches)
    }

    /// A term's match stem: inflection suffixes trimmed so "located" also hits
    /// "location" and "checklists" hits "checklist".
    static func stem(_ term: String) -> String {
        for suffix in ["ations", "ation", "ions", "ing", "ion", "ies", "es", "ed", "s"] {
            if term.hasSuffix(suffix), term.count - suffix.count >= 4 {
                return String(term.dropLast(suffix.count))
            }
        }
        return term
    }

    /// Ranks FILES by rarity-weighted distinct-stem coverage, then returns one
    /// synthetic hit per top file containing every matching paragraph (budget-
    /// capped). Letting the model read all matching paragraphs beats trying to
    /// guess the single "answer paragraph" by keyword density.
    static func best(
        terms: [String],
        root: String,
        wantDigits: Bool,
        maxMatches: Int,
        candidateURLs: [URL]? = nil
    ) -> [Retrieved] {
        var budget = ScanBudget(limits: IOLimits())
        return (try? bestCancellable(
            terms: terms,
            root: root,
            wantDigits: wantDigits,
            maxMatches: maxMatches,
            candidateURLs: candidateURLs,
            budget: &budget
        )) ?? []
    }

    private static func bestCancellable(
        terms: [String],
        root: String,
        wantDigits: Bool,
        maxMatches: Int,
        candidateURLs: [URL]?,
        budget: inout ScanBudget
    ) throws -> [Retrieved] {
        let fm = FileManager.default
        guard !terms.isEmpty else { return [] }
        let stems = Array(Set(terms.map(stem)))
        let textExts: Set<String> = ["md", "txt", "csv", "json", "toml", "yaml", "yml", "rtf", "html"]

        let urls: [URL]
        if let candidateURLs {
            urls = candidateURLs
        } else {
            urls = try recursiveFiles(root: root, budget: &budget)
        }

        var files: [(name: String, path: String, content: String, lower: String)] = []
        for url in urls {
            try Task.checkCancellation()
            guard !budget.expired else { break }
            let name = relativePath(url.path, root: root)
            guard !name.hasSuffix(".smfs-error.txt") else { continue }
            let nameLower = name.lowercased()
            let nameMatches = stems.contains { nameLower.contains($0) }
            let ext = url.pathExtension.lowercased()
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            let fileSize = attrs?[.size] as? Int ?? 0
            let allowance = min(fileSize, budget.remainingBytes, budget.limits.maximumBytesPerFile)
            var content = ""
            if textExts.contains(ext), allowance > 0,
               let handle = try? FileHandle(forReadingFrom: url) {
                let data = (try? handle.read(upToCount: allowance)) ?? nil
                try? handle.close()
                if let data {
                    budget.consume(data.count)
                    content = String(decoding: data, as: UTF8.self)
                }
            }
            let lower = content.lowercased()
            guard nameMatches || stems.contains(where: { lower.contains($0) }) else {
                continue
            }
            files.append((name, url.path, content, lower))
        }

        // Rarity: a stem found in few files is a strong signal ("prune"),
        // one found everywhere is weak ("resume" across job notes).
        var docFreq: [String: Int] = [:]
        for (index, file) in files.enumerated() {
            if index.isMultiple(of: 64) { try Task.checkCancellation() }
            guard !budget.expired else { break }
            let searchable = file.lower + "\n" + file.name.lowercased()
            for s in stems where searchable.contains(s) { docFreq[s, default: 0] += 1 }
        }
        func weight(_ s: String) -> Double {
            let df = docFreq[s] ?? 0
            return df == 0 ? 0 : (df <= 2 ? 3.0 : (df <= 5 ? 1.5 : 1.0))
        }

        // Global line-level scoring: structured facts live on single lines
        // ("- Location: Fremont, CA", "| resume_file | Bansal Resume 2026.pdf",
        // "- Rows before: 421"). Every matching line in every file competes,
        // so one rare-term file can't crowd out the actual answer line.
        struct Line { let score: Double; let text: String; let file: Int }
        var lines: [Line] = []
        for (i, file) in files.enumerated() {
            try Task.checkCancellation()
            guard !budget.expired else { break }
            // The filename itself matching several stems means the question is
            // *about this document* — its leading lines are the answer even
            // when they don't repeat the query's words (tables, lists).
            let nameLower = file.name.lowercased()
            let titleMatches = stems.filter { nameLower.contains($0) }.count
            let contentMatches = stems.contains { file.lower.contains($0) }
            guard contentMatches || titleMatches > 0 else { continue }
            if titleMatches > 0 {
                lines.append(Line(
                    score: 5.0 + Double(titleMatches),
                    text: "File: \((file.name as NSString).lastPathComponent)\nLocation: \(file.path)",
                    file: i
                ))
            }
            if !file.content.isEmpty, titleMatches >= 2 {
                var kept = 0
                for (lineIndex, rawLine) in file.content.components(separatedBy: "\n").enumerated() {
                    if lineIndex.isMultiple(of: 64) { try Task.checkCancellation() }
                    guard !budget.expired else { break }
                    let line = rawLine.trimmingCharacters(in: .whitespaces)
                    guard !line.isEmpty, line.count < 400 else { continue }
                    lines.append(Line(score: 4.0 + Double(titleMatches), text: line, file: i))
                    kept += 1
                    if kept >= 12 { break }
                }
            }
            var heading = ""
            for (lineIndex, rawLine) in file.content.components(separatedBy: "\n").enumerated() {
                if lineIndex.isMultiple(of: 64) { try Task.checkCancellation() }
                guard !budget.expired else { break }
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard !line.isEmpty, line.count < 400 else { continue }
                if line.hasPrefix("#") { heading = line; continue }
                let lower = line.lowercased()
                let headingLower = heading.lowercased()
                var score = 0.0
                var directMatches = 0
                for s in stems {
                    if lower.contains(s) { score += weight(s); directMatches += 1 }
                    else if headingLower.contains(s) { score += weight(s) * 0.4 }
                }
                guard score > 0 else { continue }
                // Field-key lines ("key: value" / table rows) assert facts.
                if lower.range(of: #"^[\s\-*|>]*[\w /]{0,24}[:|]"#, options: .regularExpression) != nil, directMatches > 0 {
                    score += 1.5
                }
                if wantDigits {
                    score += line.rangeOfCharacter(from: .decimalDigits) != nil ? 1.5 : -0.5
                }
                let chunk = heading.isEmpty ? line : "\(heading) → \(line)"
                lines.append(Line(score: score, text: chunk, file: i))
            }
        }

        // Keep the top-scoring lines within a small budget, grouped per file
        // (≤ maxMatches files so citations stay legible).
        var byFile: [Int: [String]] = [:]
        var fileOrder: [Int] = []
        var snippetBudget = 1100
        try Task.checkCancellation()
        for line in lines.sorted(by: { $0.score > $1.score }) {
            guard snippetBudget - line.text.count > 0 else { continue }
            if byFile[line.file] == nil {
                guard fileOrder.count < maxMatches else { continue }
                fileOrder.append(line.file)
                byFile[line.file] = []
            }
            byFile[line.file]!.append(line.text)
            snippetBudget -= line.text.count
        }
        return fileOrder.map { idx in
            let name = files[idx].name
            return Retrieved(
                memory: byFile[idx]!.joined(separator: "\n"), similarity: 0.55,
                source: SourceLocator(
                    docId: "",
                    path: files[idx].path,
                    title: ((name as NSString).lastPathComponent as NSString).deletingPathExtension
                ))
        }
    }

    private static func recursiveFiles(root: String, budget: inout ScanBudget) throws -> [URL] {
        let rootURL = URL(fileURLWithPath: root, isDirectory: true)
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var urls: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            guard !budget.expired else { break }
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true
            else { continue }
            guard budget.admitFile() else { break }
            urls.append(url)
        }
        try Task.checkCancellation()
        return urls.sorted { $0.path < $1.path }
    }

    private static func relativePath(_ path: String, root: String) -> String {
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard path.hasPrefix(prefix) else { return (path as NSString).lastPathComponent }
        return String(path.dropFirst(prefix.count))
    }

    /// The full rescue: find salient-but-uncovered terms, grep the mount for
    /// them, and merge the hits. For count/date questions the whole salient
    /// set is searched (the answer's digits are often in a paragraph retrieval
    /// missed even when every term is "covered"). Returns the (possibly
    /// extended) evidence and a reasoning note when anything was rescued.
    public static func rescue(query: String, evidence: [Retrieved],
                              mountRoot: String) -> ([Retrieved], String?) {
        (try? rescueCancellable(query: query, evidence: evidence, mountRoot: mountRoot))
            ?? (evidence, nil)
    }

    /// Throwing variant used by the query service so cancellation terminates
    /// the filesystem scan instead of being mistaken for an empty result.
    public static func rescueCancellable(
        query: String,
        evidence: [Retrieved],
        mountRoot: String,
        limits: IOLimits = IOLimits()
    ) throws -> ([Retrieved], String?) {
        try Task.checkCancellation()
        let terms = salientTerms(query)
        let numeric = NumericReasoner.isNumericQuestion(query)
            || query.lowercased().contains("when ")
        let missing = uncovered(terms: terms, in: evidence)
        let lowerQuery = query.lowercased()
        let mentionedExtension = lowerQuery
            .components(separatedBy: .whitespacesAndNewlines)
            .contains { token in
                let ext = (token.trimmingCharacters(in: .punctuationCharacters) as NSString)
                    .pathExtension.lowercased()
                return !ext.isEmpty && ext.count <= 8
            }
        let explicitFileLookup = mentionedExtension
            || ["filename", "file name", "file path", "folder", " pdf", "document"]
                .contains { lowerQuery.contains($0) }
        guard !missing.isEmpty || numeric || explicitFileLookup else {
            return (evidence, nil)
        }
        // A filename matching ≥2 query stems means the user is asking about
        // that document — always pull its actual lines (memories are distilled
        // summaries and often drop the concrete values being asked for).
        let stems = terms.map(stem)
        var budget = ScanBudget(limits: limits)
        let candidates = try recursiveFiles(root: mountRoot, budget: &budget)
        try Task.checkCancellation()
        let titleMatch = explicitFileLookup && candidates.contains { url in
            stems.filter { url.lastPathComponent.lowercased().contains($0) }.count >= 2
        }
        guard !missing.isEmpty || numeric || titleMatch else { return (evidence, nil) }

        let searchTerms = (numeric || titleMatch) ? terms : missing
        var hits = try bestCancellable(
            terms: searchTerms,
            root: mountRoot,
            wantDigits: numeric,
            maxMatches: 3,
            candidateURLs: candidates,
            budget: &budget
        )
        try Task.checkCancellation()

        // With no semantic evidence, a lone generic word is not enough to
        // promote a random local file into generation context. Require two
        // distinct query concepts in the same result, an exact structured
        // identifier, or strong filename coverage.
        if evidence.isEmpty {
            let identifiers = exactIdentifiers(in: query)
            hits = hits.filter {
                isMeaningfulEmptyResult(
                    $0,
                    query: query,
                    stems: Set(searchTerms.map(stem)),
                    exactIdentifiers: identifiers,
                    explicitFileLookup: explicitFileLookup
                )
            }
        }
        var merged = evidence
        let existing = Set(evidence.map { $0.memory.prefix(120) })
        var added = false
        for hit in hits where !existing.contains(hit.memory.prefix(120)) {
            merged.append(hit)
            added = true
        }
        guard added else { return (evidence, nil) }
        let label = searchTerms.prefix(4).joined(separator: "”, “")
        return (merged, "Grepped your files for “\(label)”")
    }

    private static func exactIdentifiers(in query: String) -> [String] {
        query
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,?!()[]{}\"'")) }
            .filter { token in
                guard token.count >= 4 else { return false }
                let hasLetter = token.contains(where: \.isLetter)
                let hasNumber = token.contains(where: \.isNumber)
                return (hasLetter && hasNumber)
                    || token.contains("@")
                    || token.filter({ $0 == "-" || $0 == "_" }).count >= 2
            }
            .map { $0.lowercased() }
    }

    private static func isMeaningfulEmptyResult(
        _ hit: Retrieved,
        query: String,
        stems: Set<String>,
        exactIdentifiers: [String],
        explicitFileLookup: Bool
    ) -> Bool {
        let filename = URL(fileURLWithPath: hit.source.path).lastPathComponent.lowercased()
        let searchable = "\(hit.memory) \(hit.source.title) \(filename)".lowercased()
        if exactIdentifiers.contains(where: { searchable.contains($0) }) { return true }
        if explicitFileLookup, !filename.isEmpty, query.lowercased().contains(filename) { return true }

        let distinctCoverage = stems.filter { searchable.contains($0) }.count
        if distinctCoverage >= 2 { return true }

        let queryWords = Set(query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 })
        let filenameWords = Set(filename
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 })
        let filenameCoverage = queryWords.intersection(filenameWords).count
        return explicitFileLookup && filenameCoverage >= 2
    }
}
