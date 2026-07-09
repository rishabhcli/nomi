import Foundation

/// One grep landing site: a file path (engine-relative), an optional line
/// range, and the verbatim chunk.
public struct GrepHit: Equatable, Sendable {
    public let path: String        // "" when the hit is a memory, not a file
    public let lineStart: Int?
    public let lineEnd: Int?
    public let snippet: String
    public init(path: String, lineStart: Int?, lineEnd: Int?, snippet: String) {
        self.path = path
        self.lineStart = lineStart
        self.lineEnd = lineEnd
        self.snippet = snippet
    }
}

/// The two grep modes over the mount (PLAN.md M3): flagless = semantic,
/// `-F` = literal. Faked in tests; real impl shells smfs/grep.
public protocol GrepSurface: Sendable {
    func semantic(_ query: String, scope: String?) async throws -> [GrepHit]
    func literal(_ term: String, scope: String?) async throws -> [GrepHit]
}

/// Each hop's rationale is logged — the trace powers explainability (M9).
public struct HopTrace: Equatable, Sendable {
    public let hop: Int
    public let kind: String        // "semantic" | "literal"
    public let query: String
    public let paths: [String]
    public let rationale: String
}

public struct AgenticResult: Equatable, Sendable {
    public let evidence: [Retrieved]
    public let hops: [HopTrace]
    /// Distinct source files the evidence touches (drops path-less memory hits).
    public var distinctSources: [String] {
        var seen = Set<String>()
        return evidence.map(\.source.path).filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

public enum HopDecision: Equatable, Sendable {
    case semantic(String, rationale: String)
    case literal(String, rationale: String)
    case stop(rationale: String)
}

/// Decides the next hop from the question + evidence so far. The LLM planner
/// arrives with M4's effort mapping; tests script this.
public protocol HopPlanning: Sendable {
    func nextHop(question: String, evidence: [Retrieved], hops: [HopTrace]) async -> HopDecision
}

/// The iterative semantic-grep-and-read loop over the mount. Bounded by
/// maxHops (config `agentic.max_hops`); every hop logs its rationale.
public struct AgenticGrep: Sendable {
    let surface: GrepSurface
    let planner: HopPlanning
    let maxHops: Int

    public init(surface: GrepSurface, planner: HopPlanning, maxHops: Int) {
        self.surface = surface
        self.planner = planner
        self.maxHops = maxHops
    }

    public func run(_ question: String, scope: String?) async throws -> AgenticResult {
        var evidence: [Retrieved] = []
        var hops: [HopTrace] = []
        var seen = Set<String>()

        func collect(_ hits: [GrepHit]) {
            for h in hits {
                let key = "\(h.path)|\(h.snippet)"
                guard seen.insert(key).inserted else { continue }
                evidence.append(Retrieved(
                    memory: h.snippet,
                    similarity: 0,
                    source: SourceLocator(
                        docId: "",
                        path: h.path,
                        title: h.path.isEmpty ? "memory" : (h.path as NSString).lastPathComponent)))
            }
        }

        // Hop 1 is always a semantic grep of the question itself.
        var decision = HopDecision.semantic(question, rationale: "initial semantic grep of the question")
        while hops.count < maxHops {
            switch decision {
            case .stop:
                return AgenticResult(evidence: evidence, hops: hops)
            case .semantic(let q, let why):
                let hits = try await surface.semantic(q, scope: scope)
                hops.append(HopTrace(hop: hops.count + 1, kind: "semantic", query: q,
                                     paths: hits.map(\.path), rationale: why))
                collect(hits)
            case .literal(let term, let why):
                let hits = try await surface.literal(term, scope: scope)
                hops.append(HopTrace(hop: hops.count + 1, kind: "literal", query: term,
                                     paths: hits.map(\.path), rationale: why))
                collect(hits)
            }
            decision = await planner.nextHop(question: question, evidence: evidence, hops: hops)
        }
        return AgenticResult(evidence: evidence, hops: hops)
    }
}

/// Real grep surface: `smfs grep` (semantic) + `/usr/bin/grep -rFn` (literal).
public struct SMFSGrep: GrepSurface {
    let smfsPath: String
    let containerTag: String
    let apiKey: String
    let apiURL: String
    let mountRoot: String

    public init(smfsPath: String, containerTag: String, apiKey: String, apiURL: String, mountRoot: String) {
        self.smfsPath = smfsPath
        self.containerTag = containerTag
        self.apiKey = apiKey
        self.apiURL = apiURL
        self.mountRoot = mountRoot
    }

    /// Output shape: `<filepath>:<line_start>-<line_end>:<chunk>`; `#` lines
    /// are usage banner; `(unknown)` rows are memory-level hits (no file).
    public static func parseSemanticOutput(_ out: String) -> [GrepHit] {
        var hits: [GrepHit] = []
        for line in out.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty, !t.hasPrefix("#") else { continue }
            if t.hasPrefix("(unknown):") {
                hits.append(GrepHit(path: "", lineStart: nil, lineEnd: nil,
                                    snippet: String(t.dropFirst("(unknown):".count))))
                continue
            }
            // /path/file.md:12-14:chunk text
            let parts = t.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3 else { continue }
            let range = parts[1].split(separator: "-").compactMap { Int($0) }
            hits.append(GrepHit(path: String(parts[0]),
                                lineStart: range.first,
                                lineEnd: range.count > 1 ? range[1] : range.first,
                                snippet: String(parts[2])))
        }
        return hits
    }

    /// `grep -rFn` output: `<abs path>:<line>:<text>`; paths are made
    /// engine-relative to the mount root.
    public static func parseLiteralOutput(_ out: String, mountRoot: String) -> [GrepHit] {
        var hits: [GrepHit] = []
        for line in out.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3, let n = Int(parts[1]) else { continue }
            var path = String(parts[0])
            if path.hasPrefix(mountRoot) { path = String(path.dropFirst(mountRoot.count)) }
            hits.append(GrepHit(path: path, lineStart: n, lineEnd: n, snippet: String(parts[2])))
        }
        return hits
    }

    public func semantic(_ query: String, scope: String?) async throws -> [GrepHit] {
        var args = ["grep", "--tag", containerTag, "--key", apiKey, "--api-url", apiURL, query]
        if let scope { args.append(scope) }
        return Self.parseSemanticOutput(try Subprocess.capture(smfsPath, args))
    }

    public func literal(_ term: String, scope: String?) async throws -> [GrepHit] {
        let root = scope ?? mountRoot
        // grep exits 1 on zero matches — that is a valid empty result.
        let out = (try? Subprocess.capture("/usr/bin/grep", ["-rFn", term, root])) ?? ""
        return Self.parseLiteralOutput(out, mountRoot: mountRoot)
    }
}

public enum Subprocess {
    public static func capture(_ path: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        // Discard stderr rather than pipe it: nothing reads a stderr Pipe here,
        // so a child that writes >~64KB to stderr (e.g. `grep -rFn` emitting a
        // permission-denied line per unreadable file over the mount) would block
        // on the full pipe while we block on readDataToEndOfFile(stdout) → hang.
        p.standardError = FileHandle.nullDevice
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
